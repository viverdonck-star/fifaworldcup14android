// Writes a resolved render target region straight into the texture that
// samples the resolve's output (resolve_to_texture), instead of untiling the
// resolve's guest memory into it. Red and blue are swapped when the resolve
// swapped them in memory (RB_COPY_DEST_INFO copy_dest_swap).

cbuffer XeResolveToTextureConstants : register(b0) {
  uint xe_r2t_width;
  uint xe_r2t_height;
  uint xe_r2t_swap_red_blue;
};

Texture2D<float4> xe_r2t_source : register(t0);
RWTexture2D<unorm float4> xe_r2t_dest : register(u0);

[numthreads(8, 8, 1)] void main(uint3 xe_thread_id : SV_DispatchThreadID) {
  if (xe_thread_id.x >= xe_r2t_width || xe_thread_id.y >= xe_r2t_height) {
    return;
  }
  float4 color = xe_r2t_source[xe_thread_id.xy];
  xe_r2t_dest[xe_thread_id.xy] = xe_r2t_swap_red_blue ? color.bgra : color;
}
