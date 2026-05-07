#pragma once

#include "ByteTrack/Rect.h"

namespace byte_track
{
struct Object
{
    Rect<float> rect;
    int label;
    float prob;

    Object() = default;

    Object(const Rect<float> &_rect,
           const int &_label,
           const float &_prob);
};
}