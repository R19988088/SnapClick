#include "../SnapClick/Core/AudioRingBuffer.h"

#include <assert.h>

int main(void) {
    SCAudioRingBuffer *ring = SCAudioRingBufferCreate(4);
    assert(ring);
    assert(SCAudioRingBufferGetGain(ring) == 1.0f);
    SCAudioRingBufferSetGain(ring, 0.5f);
    assert(SCAudioRingBufferGetGain(ring) == 0.5f);
    SCAudioRingBufferSetGain(ring, 0.0f);
    assert(SCAudioRingBufferGetGain(ring) == 0.0f);
    SCAudioRingBufferSetGain(ring, 1.0f);

    const float first[] = {1, 2, 3};
    assert(SCAudioRingBufferWrite(ring, first, 3) == 3);

    float output[4] = {-1, -1, -1, -1};
    assert(SCAudioRingBufferRead(ring, output, 2) == 2);
    assert(output[0] == 1 && output[1] == 2);

    const float second[] = {4, 5, 6};
    assert(SCAudioRingBufferWrite(ring, second, 3) == 3);
    assert(SCAudioRingBufferRead(ring, output, 4) == 4);
    assert(output[0] == 3 && output[1] == 4 && output[2] == 5 && output[3] == 6);

    assert(SCAudioRingBufferRead(ring, output, 2) == 0);
    assert(output[0] == 0 && output[1] == 0);

    SCAudioRingBufferDestroy(ring);
    return 0;
}
