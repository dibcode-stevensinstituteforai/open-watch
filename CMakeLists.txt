cmake_minimum_required(VERSION 3.20)
project(person_tracker)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(OpenCV REQUIRED)

# --- Eigen Path Logic ---
if(WIN32)
    set(EIGEN3_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include/eigen3")
else()
    # Standard location for libeigen3-dev on Ubuntu
    set(EIGEN3_INCLUDE_DIR "/usr/include/eigen3")
endif()

set(BYTETRACK_SOURCES
    bytetrack/BYTETracker.cpp
    bytetrack/KalmanFilter.cpp
    bytetrack/lapjv.cpp
    bytetrack/Object.cpp
    bytetrack/Rect.cpp
    bytetrack/STrack.cpp
)

if(WIN32)
    add_executable(tracker_windows src/tracker_windows.cpp ${BYTETRACK_SOURCES})
    target_include_directories(tracker_windows PRIVATE ${EIGEN3_INCLUDE_DIR} ${CMAKE_SOURCE_DIR})
    target_link_libraries(tracker_windows PRIVATE ${OpenCV_LIBS})
else()
    # Renamed to person_detector_linux as per your request
    add_executable(person_detector_linux src/tracker_linux.cpp ${BYTETRACK_SOURCES})
    target_include_directories(person_detector_linux PRIVATE ${EIGEN3_INCLUDE_DIR} ${CMAKE_SOURCE_DIR})
    target_link_libraries(person_detector_linux PRIVATE ${OpenCV_LIBS})
endif()

message(STATUS "Target System: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Eigen Path:    ${EIGEN3_INCLUDE_DIR}")