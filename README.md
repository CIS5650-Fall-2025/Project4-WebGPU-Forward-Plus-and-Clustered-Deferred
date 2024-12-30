WebGL Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Nadine Adnane
  * [LinkedIn](https://www.linkedin.com/in/nadnane/)
* Tested on my personal laptop (ASUS ROG Zephyrus M16):
* **OS:** Windows 11
* **Processor:** 12th Gen Intel(R) Core(TM) i9-12900H, 2500 Mhz, 14 Core(s), 20 Logical Processor(s) 
* **GPU:** NVIDIA GeForce RTX 3070 Ti Laptop GPU

### Live Demo 👀

[Click here to run my project in your browser!](http://nadnane.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred)

## Introduction
In this project, I implemented two advanced rendering techniques—Forward+ Shading and Clustered Deferred Shading—as part of an exploration into WebGPU. WebGPU is an API that allows applications on the web to take full advantage of GPU hardware capabilities, enabling much faster execution of graphical computations. The scene is based on the Sponza Atrium model, augmented with a large number of point lights, and includes a GUI menu to toggle between different rendering modes.

## Naive Renderer (Forward Rendering)
In the naive renderer, each fragment is checked against every light in the scene, which quickly becomes inefficient. For example, if a cube is present in the scene, the algorithm will check each light for every pixel of the cube—even for pixels that will be overwritten. This results in unnecessary computations and significant performance overhead. While this approach can technically render the scene, it is far from optimal and can be improved.

## Forward+
The Forward+ implementation optimizes the naive approach by restricting the light checks to only those within the cluster that the current fragment resides in. This way, only the lights that actually affect the current fragment are considered, significantly reducing unnecessary calculations.

Clusters are portions of the 3D space, and each cluster corresponds to a tile on the 2D screen. These clusters are aligned with the camera's view, not the scene itself, meaning that when the camera moves, the clusters' positions in world space adjust accordingly.

A compute shader is used to calculate the bounds of each cluster in screen space (2D), including the starting and ending depth. The screen-space depth bounds are then converted into view-space coordinates.

Lights are assigned to clusters, and the shader keeps track of the number of lights within each cluster, up to a hardcoded maximum. For each light, the algorithm checks if it intersects with the cluster's bounding box, adding it to the cluster if there is an intersection.

However, the Forward+ approach still suffers from the problem of overdraw, as fragments that will be overwritten in later passes are still being processed, wasting computational resources.

## Clustered Deferred
Clustered Deferred Shading takes a different approach by separating geometry rendering from shading. During the initial pass, each object in the scene is drawn to G-buffers, which store the albedo, normal, and position data. This results in a relatively simple rendering pass since it only outputs to textures. In subsequent passes, the data is read from the G-buffers to perform the final shading, allowing for more efficient rendering.

This method helps avoid the overdraw problem because only one fragment is processed per pixel, even in scenes with substantial depth.

The light clustering process in Clustered Deferred is similar to Forward+ Shading. The same compute shaders can be used, as they are responsible for calculating cluster bounds and assigning lights. The world position of each fragment can be reconstructed from the depth buffer. With just three textures—the diffuse color, depth, and normal buffers—the entire scene can be rendered, with much improved efficiency.

### GIFs
![Naive](naive.gif)
![Forward+](forward+.gif)
![Clustered Deferred](clustered.gif)

### Performance Analysis

As expected, the naive method is slowest. The forward+ method is noticeably faster, but the clustered deferred method is the fastest and smoothest of the three.

In general, the three rendering techniques implemented in this project differ in how they handle shading.

Forward Rendering processes all objects in a single pass, applying shading for all lights, regardless of occlusion. This method tends to be less efficient since it doesn't account for which lights are visible.

Forward+ Rendering improves performance by clustering lights in a compute pass. It then shades only the visible lights for each object, reducing unnecessary calculations. However, it still shades all objects regardless of occlusion, which can limit performance, especially when there is heavy occlusion. In cases of minimal occlusion, forward+ rendering might outperform clustered deferred rendering, as it skips the geometry pass.

Clustered Deferred Rendering further enhances this approach by separating the geometry and shading passes. This allows for more efficient shading, as only visible objects are shaded after their visibility is determined. This method is expected to deliver the best average performance, as it consistently shades a number of pixels proportional to the total fragments on screen.

Overall, clustered deferred shading is the most efficient, while forward rendering is the slowest due to its lack of optimization for visible lights and occlusion. From what I observed, the clustered deferred technique consistently achieved around 60 FPS with around 500 lights in the scene. This is a huge performance boost compared to the other two methods, which never reached above 15 FPS with the same number of lights. The naive implementation consistently showed only around 5 FPS, and even without knowing the FPS, the visual difference in terms of lag is hard to miss!

### Credits
- [A Primer On Efficient Rendering Algorithms & Clustered Shading](https://www.aortiz.me/2018/12/21/CG.html#deferred-shading)
- [Clustered Deferred and Forward Shading](https://www.cse.chalmers.se/~uffe/clustered_shading_preprint.pdf)
- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
