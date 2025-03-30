# Godot SSR Water 

![Demo Scene Screenshot](screenshot.png)

## What is this about?

This intends to solve the problem that the SSR (Screen Space Reflection) implementation of Godot 4.X is limited to surfaces that are not transparent. For a water shader it is often necessary to support both transparency and reflections. In a lot of cases this can be worked around with reflection probes, but the need for SSR stands, especially because SSR works quiet well for water. The only solution is to write a custom SSR shader for that matter.

This is a full water shader implementation supporting:

- Screen Space Reflection
- Transparency
- 3D waves
- Edge detection
- Normal textures for a varied surface
- Fake Refraction

This repository includes the shader and a demo scene.

The SSR part of the shader is done in a function of its own, so it should be possible to use the SSR functionality separately.

## Godot Version

Godot 4.4.1 (the shader code itself should generally run on all Godot versions 4.3+)

## Usage

Load the project in Godot and hit "Run".

Use the shader settings to both change look and performance of the shader. 

Especially the SSR settings have great impact on the shaders performance. In many cases low quality settings might be more than enough (low value distance, high value resolution).

### Shader Settings

| Setting                            | Description |
| --------                           | ------- |
| Color Shallow                      | The color that is shown in shallow water (and is mixed with visible objects beneath the surface, when transparency is > 0.0) |
| Color Deep                         | The color that is shown in deep water. |
| Transparency                       | The transparency of the water. |
| Metallic                           | The metallic property of the water. |
| Roughness                          | The roughness property of the water. |
| Max Visible Depth                  | The depth when only color deep is rendered. |
| Wave A Move Direction              | The 2D vector of the Wave A texture. |
| Wave B Move Direction              | The 2D vector of the Wave B texture. |
| Wave Noise Scale A                 | Scale of the 3D waves interpretation for wave A. Higher means wider waves. |
| Wave Noise Scale B                 | Scale of the 3D waves interpretation for wave B. Higher means wider waves. |
| Wave Time Scale A                  | The wave A speed. |
| Wave Time Scale B                  | The wave B speed. |
| Wave Height Scale                  | The y-height of waves interpreted from the wave textures. |
| Wave Normal Flatness               | The flatness of the new calculated normals. Higher values are smoother. |
| Surface Normals Move Direction A   | The 2D vector of the Surface Normals A texture. For details on the water surface. |
| Surface Normals Move Direction B   | The 2D vector of the Surface Normals B texture. This is merged with the details from A. |
| Surface Texture Roughness          | How rough the detail normals will look. |
| Surface Texture Scale              | Scale of the texture interpretation. Higher means smaller details.|
| Surface Texture Time Scale         | The speed the details move across the surface. |
| SSR Resolution                     | The distance the ray-marching algorithm moves per step. Smaller values are better but slower. |
| SSR Max Travel                     | The maximum distance the ray will travel before giving up. Longer is better but slower. 0 deactivates SSR. |
| SSR Max Diff                       | The maximum diff from geometry that is counted as a ray-march hit. No performance impact. Low values might miss geometry, high values might create false positives. Aim for good looks. |
| SSR Mix Strength                   | How visible the reflections are on the surface of the water. |
| SSR Screen Border Fadeout          | Strength of fade-out effect on reflections close to the screen borders |
| Refraction Intensity               | The intensity of the refraction effect. 0 is no refraction at all. |
| Border Color                       | The coastal border color. This is the foam around objects in the water. |
| Border Scale                       | The size of the coastal border. |
| Border Near                        | Near plane for linear depth calculation for coastal borders. Good values improve the precision. Should be < Border Far. (Default: 0.5) |
| Border Far                         | Far plane for linear depth calculation for coastal borders. Good values improve the precision depending on your scene scale. Should be > Border Near. (Default: 300.0) |
| Cut Out X                          | The cut out in X direction. No pixels are rendered here. This can be useful, if an object resides in the middle that should not have a water surface inside. |
| Cut Out Y                          | The cut out in Y direction. No pixels are rendered here. This can be useful, if an object resides in the middle that should not have a water surface inside. |
| Wave A                             | The height texture for the wave layer A. Should be seamless and black and white, can be noise. |
| Wave B                             | The height texture for the wave layer B. Should be seamless and black and white, can be noise. |
| Surface Normals A                  | The normals texture with the surface normals for A. Should be seamless, can be noise. |
| Surface Normals B                  | The normals texture with the surface normals for A. Should be seamless, can be noise.  |

## Performance

Should run well in most cases. I’ve tested it at 60fps on the Steam Deck at an SSR resolution of 2.0 without any other optimizing and the demo is out of the box rock steady at 60fps at 50% GPU with 2.3 watts.

(c) Marcel Bankmann 2023 - present
