// Person Tracking for Windows — MobileNet-SSD + ByteTrack
#include <iostream>
#include <fstream>
#include <opencv2/opencv.hpp>
#include <opencv2/dnn.hpp>
#include <vector>
#include "bytetrack/BYTETracker.h"
#include "bytetrack/Object.h"

int main() {
    std::cout << "=== Person Tracker - Windows ===" << std::endl;
    std::cout << "OpenCV version: " << CV_VERSION << std::endl;

    // --- 1. Load MobileNet-SSD model ---
    // Model files are committed at <repo>/models/. The Release binary lives
    // in <repo>/build-windows/Release/, so "../../models/..." is the
    // canonical relative path. The other entries are convenience fallbacks
    // for running from the repo root or from build-windows/ directly. All
    // paths are repo-relative so the program works on any machine.
    std::vector<std::string> prototxtPaths = {
        "../../models/MobileNetSSD_deploy.prototxt",
        "../models/MobileNetSSD_deploy.prototxt",
        "models/MobileNetSSD_deploy.prototxt"
    };
    std::vector<std::string> caffemodelPaths = {
        "../../models/MobileNetSSD_deploy.caffemodel",
        "../models/MobileNetSSD_deploy.caffemodel",
        "models/MobileNetSSD_deploy.caffemodel"
    };

    cv::dnn::Net net;
    bool modelLoaded = false;
    for (size_t i = 0; i < prototxtPaths.size(); i++) {
        try {
            net = cv::dnn::readNetFromCaffe(prototxtPaths[i], caffemodelPaths[i]);
            if (!net.empty()) {
                std::cout << "Model loaded from: " << prototxtPaths[i] << std::endl;
                modelLoaded = true;
                break;
            }
        } catch (...) {
            continue;
        }
    }
    if (!modelLoaded) {
        std::cerr << "Error loading model: could not find MobileNet-SSD files in any known location." << std::endl;
        return 1;
    }
    net.setPreferableBackend(cv::dnn::DNN_BACKEND_OPENCV);
    net.setPreferableTarget(cv::dnn::DNN_TARGET_CPU);

    // --- 2. Open video ---
    // Default test video is committed at <repo>/videos/video1.mp4.
    // The Release binary lives in <repo>/build-windows/Release/, so
    // "../../videos/..." is the canonical relative path. The other entries
    // are convenience fallbacks for running from the repo root or from
    // build-windows/ directly (single-config generators).
    std::vector<std::string> videoPaths = {
        "../../videos/video1.mp4",
        "../videos/video1.mp4",
        "videos/video1.mp4"
    };
    cv::VideoCapture cap;
    for (const auto& path : videoPaths) {
        cap.open(path);
        if (cap.isOpened()) {
            std::cout << "Video opened: " << path << std::endl;
            break;
        }
    }
    if (!cap.isOpened()) {
        std::cerr << "Error: Could not open video file!" << std::endl;
        return 1;
    }

    int width  = (int)cap.get(cv::CAP_PROP_FRAME_WIDTH);
    int height = (int)cap.get(cv::CAP_PROP_FRAME_HEIGHT);
    int total  = (int)cap.get(cv::CAP_PROP_FRAME_COUNT);
    double fps = cap.get(cv::CAP_PROP_FPS);

    std::cout << "Video: " << width << "x" << height
              << "  FPS: " << fps
              << "  Frames: " << total << std::endl;
    std::cout << "Press ESC to exit" << std::endl;

    // --- 3. Init ByteTrack ---
    // BYTETracker(fps, buffer_size)
    // buffer_size = how many frames to keep a lost track alive
    byte_track::BYTETracker tracker(fps, 60);

    // --- 4. Detection config ---
    const int   PERSON_CLASS   = 15;
    const float CONF_THRESHOLD = 0.4f;  // slightly lower to feed more detections to tracker

    // Colors per ID (cycle through 10 colors)
    std::vector<cv::Scalar> colors = {
        {255, 0,   0  }, {0,   255, 0  }, {0,   0,   255},
        {255, 255, 0  }, {0,   255, 255}, {255, 0,   255},
        {128, 255, 0  }, {255, 128, 0  }, {0,   128, 255},
        {128, 0,   255}
    };

    cv::Mat frame;
    int frameNum = 0;



    // --- Open CSV File ---
    std::ofstream csvFile("tracking_data.csv");
    if (!csvFile.is_open()) {
        std::cerr << "Failed to open CSV file for writing!" << std::endl;
        return 1;
    }
    // Write the header row
    csvFile << "x,y,width,height,time_in_seconds,track_id\n";




    while (cap.read(frame)) {
        if (frame.empty()) break;
        frameNum++;

        // --- 5. Pre-processing ---
        cv::Mat blob = cv::dnn::blobFromImage(
            frame, 0.007843, cv::Size(300, 300),
            cv::Scalar(127.5, 127.5, 127.5), false
        );
        net.setInput(blob);

        // --- 6. Inference ---
        cv::Mat detections = net.forward();

        // --- 7. Parse detections into byte_track::Object vector ---
        std::vector<byte_track::Object> objects;
        float* data = (float*)detections.data;
        int numDetections = detections.size[2];

        for (int i = 0; i < numDetections; i++) {
            float confidence = data[i * 7 + 2];
            int   classId    = (int)data[i * 7 + 1];

            if (classId == PERSON_CLASS && confidence > CONF_THRESHOLD) {
                float x1 = data[i * 7 + 3] * width;
                float y1 = data[i * 7 + 4] * height;
                float x2 = data[i * 7 + 5] * width;
                float y2 = data[i * 7 + 6] * height;

                // Clamp
                x1 = std::max(0.f, std::min(x1, (float)(width  - 1)));
                y1 = std::max(0.f, std::min(y1, (float)(height - 1)));
                x2 = std::max(0.f, std::min(x2, (float)(width  - 1)));
                y2 = std::max(0.f, std::min(y2, (float)(height - 1)));

                byte_track::Object obj;
                obj.rect  = byte_track::Rect<float>(x1, y1, x2 - x1, y2 - y1);
                obj.label = 0;       // we only have persons so label=0
                obj.prob  = confidence;
                objects.push_back(obj);
            }
        }

        // --- 8. Update tracker ---
        auto tracked = tracker.update(objects);


        
        // Calculate current time in seconds
        double time_in_seconds = static_cast<double>(frameNum) / fps;



        // --- 9. Draw tracked persons ---
        for (const auto& track : tracked) {
            int id     = track->getTrackId();
            auto rect  = track->getRect();

            int x1 = (int)rect.x();
            int y1 = (int)rect.y();
            int x2 = (int)(rect.x() + rect.width());
            int y2 = (int)(rect.y() + rect.height());

            // Clamp
            x1 = std::max(0, std::min(x1, width  - 1));
            y1 = std::max(0, std::min(y1, height - 1));
            x2 = std::max(0, std::min(x2, width  - 1));
            y2 = std::max(0, std::min(y2, height - 1));

            cv::Scalar color = colors[id % colors.size()];

            // Bounding box
            cv::rectangle(frame,
                cv::Point(x1, y1), cv::Point(x2, y2),
                color, 2);

            // Label
            std::string label = "ID:" + std::to_string(id);
            int baseline = 0;
            cv::Size labelSize = cv::getTextSize(
                label, cv::FONT_HERSHEY_SIMPLEX, 0.6, 2, &baseline);
            cv::rectangle(frame,
                cv::Point(x1, y1 - labelSize.height - 8),
                cv::Point(x1 + labelSize.width, y1),
                color, cv::FILLED);
            cv::putText(frame, label, cv::Point(x1, y1 - 4),
                cv::FONT_HERSHEY_SIMPLEX, 0.6, cv::Scalar(0, 0, 0), 2);

            
            // --- SAVE TO CSV ---
            // Calculate width and height from your existing x1, y1, x2, y2 variables
            int w = x2 - x1;
            int h = y2 - y1;
    
            // Write the data row
            csvFile << x1 << "," << y1 << "," << w << "," << h << "," << time_in_seconds << "," << id << "\n";
        }

        // --- 10. HUD ---
        std::string hud = "Frame: " + std::to_string(frameNum) +
                          "/" + std::to_string(total) +
                          "  Tracked: " + std::to_string(tracked.size());
        cv::putText(frame, hud, cv::Point(10, 30),
            cv::FONT_HERSHEY_SIMPLEX, 0.7, cv::Scalar(255, 255, 0), 2);

        cv::imshow("Person Tracker", frame);
        if (cv::waitKey(1) == 27) break;
    }

    cap.release();
    cv::destroyAllWindows();

    std::cout << "Done. Processed " << frameNum << " frames." << std::endl;
    csvFile.close();
    return 0;
}