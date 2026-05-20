// Person Tracking for Linux (WSL) — MobileNet-SSD + ByteTrack
#include <iostream>
#include <fstream>
#include <opencv2/opencv.hpp>
#include <opencv2/dnn.hpp>
#include <vector>
#include <filesystem>
#include <deque>           // Added for the temporal rolling window
#include <unordered_map>   // Added to track node graphs by ID

#include "bytetrack/BYTETracker.h"
#include "bytetrack/Object.h"

// --- Topological Algorithm State & Parameters ---
std::unordered_map<int, std::deque<cv::Point>> track_history;

const size_t MIN_NODES = 49;          // Must have at least 49 rows/nodes
const size_t MAX_HISTORY = 150;       // Max nodes to keep in memory 
const int LOITER_RADIUS = 60;         // Pixel radius that defines a "knot"
// ------------------------------------------------

int main() {
    std::cout << "=== Person Tracker - Linux/WSL ===" << std::endl;

    // --- 1. Load Model with Path Searching ---
    std::vector<std::string> prototxtPaths = {
        "../models/MobileNetSSD_deploy.prototxt",
        "models/MobileNetSSD_deploy.prototxt",
        "../../models/MobileNetSSD_deploy.prototxt"
    };
    std::vector<std::string> caffemodelPaths = {
        "../models/MobileNetSSD_deploy.caffemodel",
        "models/MobileNetSSD_deploy.caffemodel",
        "../../models/MobileNetSSD_deploy.caffemodel"
    };

    cv::dnn::Net net;
    bool modelLoaded = false;
    for (size_t i = 0; i < prototxtPaths.size(); i++) {
        try {
            net = cv::dnn::readNetFromCaffe(prototxtPaths[i], caffemodelPaths[i]);
            if (!net.empty()) {
                std::cout << "Model loaded from: " << prototxtPaths[i] << std::endl;
                modelLoaded = true; break;
            }
        } catch (...) { continue; }
    }

    if (!modelLoaded) { std::cerr << "Error: Could not load model!" << std::endl; return 1; }
    net.setPreferableBackend(cv::dnn::DNN_BACKEND_OPENCV);
    net.setPreferableTarget(cv::dnn::DNN_TARGET_CPU);

    // --- 2. Open Video ---
    std::vector<std::string> videoPaths = {
        "../videos/video1.mp4",
        "videos/video1.mp4",
        "../../videos/video1.mp4"
    };
    cv::VideoCapture cap;
    for (const auto& path : videoPaths) {
        cap.open(path);
        if (cap.isOpened()) { std::cout << "Video opened: " << path << std::endl; break; }
    }
    if (!cap.isOpened()) { std::cerr << "Error: Video not found!" << std::endl; return 1; }

    int width  = (int)cap.get(cv::CAP_PROP_FRAME_WIDTH);
    int height = (int)cap.get(cv::CAP_PROP_FRAME_HEIGHT);
    double fps = cap.get(cv::CAP_PROP_FPS);

    // --- 3. Init ByteTrack (Using your 60fps buffer preference) ---
    byte_track::BYTETracker tracker(fps, 60);
    std::filesystem::create_directories("output");

    std::vector<cv::Scalar> colors = {
        {255, 0, 0}, {0, 255, 0}, {0, 0, 255}, {255, 255, 0}, {0, 255, 255}
    };

    cv::Mat frame;
    int frameNum = 0;
    const int PERSON_CLASS = 15;

    // --- 2. OPEN CSV FILE ---
    // Saving it in the "output" folder alongside your images
    std::ofstream csvFile("output/tracking_data.csv"); 
    if (!csvFile.is_open()) {
        std::cerr << "Failed to open CSV file for writing!" << std::endl;
        return 1;
    }
    // Write the header row
    csvFile << "x,y,width,height,time_in_seconds,track_id\n";

    while (cap.read(frame)) {
        if (frame.empty()) break;
        frameNum++;

        // --- 4. Detection ---
        cv::Mat blob = cv::dnn::blobFromImage(frame, 0.007843, cv::Size(300, 300), cv::Scalar(127.5, 127.5, 127.5));
        net.setInput(blob);
        cv::Mat detections = net.forward();

        // --- 5. Convert to ByteTrack Objects ---
        std::vector<byte_track::Object> objects;
        float* data = (float*)detections.data;
        for (int i = 0; i < detections.size[2]; i++) {
            float confidence = data[i * 7 + 2];
            if ((int)data[i * 7 + 1] == PERSON_CLASS && confidence > 0.4f) {
                float x1 = data[i * 7 + 3] * width;
                float y1 = data[i * 7 + 4] * height;
                float x2 = data[i * 7 + 5] * width;
                float y2 = data[i * 7 + 6] * height;

                byte_track::Object obj;
                obj.rect = byte_track::Rect<float>(x1, y1, x2 - x1, y2 - y1);
                obj.prob = confidence;
                obj.label = 0;
                objects.push_back(obj);
            }
        }

        // --- 6. Update Tracker ---
        auto tracked = tracker.update(objects);

        // Calculate current time in seconds for the whole frame
        double time_in_seconds = static_cast<double>(frameNum) / fps;

        // --- 7. Draw and Save ---
        for (const auto& t : tracked) {
            auto r = t->getRect();
            int id = t->getTrackId();
            
            // 7.1. DECLARE AND EXTRACT VARIABLES FIRST
            int x1 = (int)r.x();
            int y1 = (int)r.y();
            int w  = (int)r.width();
            int h  = (int)r.height();

            // --- REAL-TIME TOPOLOGICAL LOITERING ALGORITHM ---
            int cx = x1 + w / 2;
            int cy = y1 + h / 2;
            cv::Point current_pt(cx, cy);
            
            track_history[id].push_back(current_pt);
            
            if (track_history[id].size() > MAX_HISTORY) {
                track_history[id].pop_front();
            }

            bool is_loitering = false;

            if (track_history[id].size() >= MIN_NODES) {
                int max_dist_sq = 0;
                
                for (const auto& pt : track_history[id]) {
                    int dx = current_pt.x - pt.x;
                    int dy = current_pt.y - pt.y;
                    int dist_sq = dx * dx + dy * dy;
                    if (dist_sq > max_dist_sq) {
                        max_dist_sq = dist_sq;
                    }
                }
                
                if (max_dist_sq < (LOITER_RADIUS * LOITER_RADIUS)) {
                    is_loitering = true;
                }
            }
            // ---------------------------------------------------

            // Adjust color and text based on algorithm logic
            cv::Scalar color = is_loitering ? cv::Scalar(0, 0, 255) : colors[id % colors.size()];
            int thickness = is_loitering ? 4 : 2;
            std::string label = "ID:" + std::to_string(id);
            if (is_loitering) {
                label += " [LOITERING]";
            }

            // 7.2. DRAW BOUNDING BOXES (using the variables)
            cv::rectangle(frame, cv::Rect(x1, y1, w, h), color, thickness);
            cv::putText(frame, label, cv::Point(x1, y1 - 5), cv::FONT_HERSHEY_SIMPLEX, 0.6, color, 2);
            
            // --- 7.3. WRITE TO CSV ---
            csvFile << x1 << "," << y1 << "," << w << "," << h << "," << time_in_seconds << "," << id << "\n";
        }

        // Save frames (every 30th or whenever someone is tracked)
        if (frameNum % 30 == 0 || !tracked.empty()) {
            if (frameNum % 5 == 0) { // Limit saving frequency
                std::string filename = "output/track_frame_" + std::to_string(frameNum) + ".jpg";
                cv::imwrite(filename, frame);
            }
        }

        if (frameNum % 50 == 0) std::cout << "Processed frame: " << frameNum << "\r" << std::flush;
    }

    std::cout << "\nDone. Processed " << frameNum << " frames. Check 'output/' folder." << std::endl;

    // --- 8. CLOSE CSV FILE ---
    csvFile.close();
    return 0;
}