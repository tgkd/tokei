#include "GlobeShared.h"

fragment half4 pixelPresent(FullscreenVertex in [[stage_in]],
                            texture2d<half> art [[texture(0)]],
                            constant float &ratio [[buffer(0)]]) {
    uint2 limit = uint2(art.get_width() - 1, art.get_height() - 1);
    uint2 cell = min(uint2(in.position.xy / ratio), limit);
    return art.read(cell);
}
