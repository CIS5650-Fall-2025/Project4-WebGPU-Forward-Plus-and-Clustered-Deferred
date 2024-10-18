WebGPU Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 2**

* CARLOS LOPEZ GARCES
  * [LinkedIn](https://www.linkedin.com/in/clopezgarces/)
  * [Personal website](https://carlos-lopez-garces.github.io/)
* Tested on: Windows 11, 13th Gen Intel(R) Core(TM) i9-13900HX @ 2.20 GHz, RAM 32GB, NVIDIA GeForce RTX 4060, personal laptop.

### Live Demo

[![](img/thumb.png)](http://TODO.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred)

### Demo Video/GIF

<video width="640" height="360" controls>
  <source src="img/video.mp4" type="video/mp4">
</video>
![](img/video.mp4)

### WebGPU-Based Rasterization Renderers

This project implements three WebGPU-based rasterization renderers that explore different techniques for handling lighting in a scene. The primary goal is to demonstrate different approaches to managing light calculations in a real-time rendering context, each with varying levels of complexity and efficiency.

## Renderers Overview

1. **Naive Renderer**
2. **Forward+ Renderer**
3. **Clustered Deferred Renderer**

### Naive Renderer

The **Naive Renderer** is the simplest, but most inefficient, of the three renderers. It computes the lighting for each fragment by iterating over all the lights in the scene. This approach is particularly inefficient for scenes with many lights, as it scales poorly when the number of lights increases.

The fragment shader computes the contribution of all lights in the scene for every fragment. This means that for each fragment, the shader loops over up to 5000 lights, regardless of their distance from the fragment or whether the light has any actual contribution to the fragment (since lights falls off with distance). This makes it inefficient for scenes with many lights and large numbers of fragments being shaded.

### Forward+ Renderer

The **Forward+ Renderer** follows an efficient light management approach known as light clustering. This approach divides the screen space into clusters, with each cluster being assigned a subset of the lights that influence that region. This way, only the lights that are relevant to a specific cluster are evaluated by the fragments within that cluster. This ensures that only a relevant subset of lights is evaluated per cluster, unlike the naive renderer, which evaluates all lights for every fragment.

Since the lights in the scene are dynamic (they can move), the light clustering must be recomputed for each frame. The clustering compute shader is invoked during every draw call, ensuring that the light information for each cluster is updated to reflect the current positions of the lights.

During rendering, each fragment identifies the cluster that corresponds to its position. The clusters are bound to the render pass and used to look up the specific lights that affect the fragment. This means that instead of evaluating all lights in the scene, each fragment only processes a small subset of lights relevant to its spatial cluster.

One of the advantages of the Forward+ Renderer is that the maximum number of lights per cluster is configurable. By adjusting this number, you can fine-tune the balance between rendering performance and lighting accuracy. Fewer lights per cluster improve performance but may lead to less detailed lighting, while allowing more lights per cluster increases lighting accuracy at some cost. While the naive renderer’s performance scales poorly with an increasing number of lights, the Forward+ approach scales much better, provided that the numnber of lights per cluster is fine-tuned for the scene.

### Clustered Deferred Renderer

The **Clustered Deferred Renderer** builds on the Forward+ approach by combining light clustering with a deferred rendering pipeline, which separates the computation of shading attributes (like albedo, normals, and positions) into an initial pass using a G-buffer; the G-buffer is generated using a compute shader.

Like the Forward+ Renderer, the Clustered Deferred Renderer divides the scene into clusters, assigning a subset of the lights to each cluster. These clusters are used during shading to limit the number of lights each fragment evaluates, optimizing performance.

After the G-buffer is generated, a fullscreen quad render pass computes the final lighting for each fragment. The G-buffer data (albedo, normals, positions) is combined with the light clusters, allowing the renderer to compute lighting efficiently for each fragment. Since the lighting is deferred, the light computations are only performed after all geometry has been processed, further optimizing performance.

- **Postprocessing with Toon Shading**: The Clustered Deferred Renderer includes the option to perform a postprocessing pass over the final rendered image. This pass applies a **toon shading effect**, which gives the scene a stylized look.

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
