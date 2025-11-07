# Formats & Channel Mappings (updated)

## Outputs
- **AmbiX FOA (ACN/SN3D)**: 4-ch WAV with channel order **W, Y, Z, X** (ACN 0..3)
- **FuMa FOA (WXYZ)**: 4-ch WAV with channel order **W, X, Y, Z** and SN3D→FuMa scaling:
  - W_fu = W_sn3d / sqrt(2)
  - {X,Y,Z}_fu = {X,Y,Z}_sn3d * sqrt(3/2)

Other targets (stereo/5.1/7.1, binaural) can be added in `Transcoder` using FOA decoders.
