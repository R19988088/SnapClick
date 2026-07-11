#include "AudioRingBuffer.h"

#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct SCAudioRingBuffer {
    float *samples;
    size_t capacity;
    atomic_uint_fast64_t readPosition;
    atomic_uint_fast64_t writePosition;
    atomic_uint_least32_t gainBits;
};

SCAudioRingBuffer *SCAudioRingBufferCreate(size_t capacitySamples) {
    if (capacitySamples == 0) return NULL;
    SCAudioRingBuffer *ring = calloc(1, sizeof(SCAudioRingBuffer));
    if (!ring) return NULL;
    ring->samples = calloc(capacitySamples, sizeof(float));
    if (!ring->samples) {
        free(ring);
        return NULL;
    }
    ring->capacity = capacitySamples;
    SCAudioRingBufferSetGain(ring, 1.0f);
    return ring;
}

void SCAudioRingBufferSetGain(SCAudioRingBuffer *ring, float gain) {
    if (!ring) return;
    uint32_t bits;
    memcpy(&bits, &gain, sizeof(bits));
    atomic_store_explicit(&ring->gainBits, bits, memory_order_release);
}

float SCAudioRingBufferGetGain(const SCAudioRingBuffer *ring) {
    if (!ring) return 0;
    const uint32_t bits = atomic_load_explicit(&ring->gainBits, memory_order_acquire);
    float gain;
    memcpy(&gain, &bits, sizeof(gain));
    return gain;
}

void SCAudioRingBufferDestroy(SCAudioRingBuffer *ring) {
    if (!ring) return;
    free(ring->samples);
    free(ring);
}

void SCAudioRingBufferReset(SCAudioRingBuffer *ring) {
    if (!ring) return;
    atomic_store_explicit(&ring->readPosition, 0, memory_order_relaxed);
    atomic_store_explicit(&ring->writePosition, 0, memory_order_relaxed);
}

size_t SCAudioRingBufferWrite(SCAudioRingBuffer *ring, const float *samples, size_t count) {
    if (!ring || !samples || count == 0) return 0;
    const uint64_t write = atomic_load_explicit(&ring->writePosition, memory_order_relaxed);
    const uint64_t read = atomic_load_explicit(&ring->readPosition, memory_order_acquire);
    const size_t freeCount = ring->capacity - (size_t)(write - read);
    count = count < freeCount ? count : freeCount;

    const size_t offset = (size_t)(write % ring->capacity);
    const size_t first = count < ring->capacity - offset ? count : ring->capacity - offset;
    memcpy(ring->samples + offset, samples, first * sizeof(float));
    memcpy(ring->samples, samples + first, (count - first) * sizeof(float));
    atomic_store_explicit(&ring->writePosition, write + count, memory_order_release);
    return count;
}

size_t SCAudioRingBufferRead(SCAudioRingBuffer *ring, float *samples, size_t count) {
    if (!ring || !samples || count == 0) return 0;
    const uint64_t read = atomic_load_explicit(&ring->readPosition, memory_order_relaxed);
    const uint64_t write = atomic_load_explicit(&ring->writePosition, memory_order_acquire);
    const size_t available = (size_t)(write - read);
    const size_t copied = count < available ? count : available;

    const size_t offset = (size_t)(read % ring->capacity);
    const size_t first = copied < ring->capacity - offset ? copied : ring->capacity - offset;
    memcpy(samples, ring->samples + offset, first * sizeof(float));
    memcpy(samples + first, ring->samples, (copied - first) * sizeof(float));
    if (copied < count) {
        memset(samples + copied, 0, (count - copied) * sizeof(float));
    }
    atomic_store_explicit(&ring->readPosition, read + copied, memory_order_release);
    return copied;
}
