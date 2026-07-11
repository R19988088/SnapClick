#ifndef SnapClick_AudioRingBuffer_h
#define SnapClick_AudioRingBuffer_h

#include <stddef.h>

typedef struct SCAudioRingBuffer SCAudioRingBuffer;

SCAudioRingBuffer *SCAudioRingBufferCreate(size_t capacitySamples);
void SCAudioRingBufferDestroy(SCAudioRingBuffer *ring);
void SCAudioRingBufferReset(SCAudioRingBuffer *ring);
size_t SCAudioRingBufferWrite(SCAudioRingBuffer *ring, const float *samples, size_t count);
size_t SCAudioRingBufferRead(SCAudioRingBuffer *ring, float *samples, size_t count);
void SCAudioRingBufferSetGain(SCAudioRingBuffer *ring, float gain);
float SCAudioRingBufferGetGain(const SCAudioRingBuffer *ring);

#endif
