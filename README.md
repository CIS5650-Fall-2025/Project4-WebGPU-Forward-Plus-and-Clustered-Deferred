WebGL Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Rahul Aggarwal
  * [LinkedIn](https://www.linkedin.com/in/rahul-aggarwal-32133a1b3/)
* Tested on: Windows 11, i7-12700H @ 2.3GHz, RTX 3050 Ti Laptop 4GB (Personal)

![teaser](img/teaser.png)

## Live Demo

[Live Demo](http://rahulaggarwal965.github.io/CIS5650-Project4-WebGPU-Forward-Plus-and-Clustered-Deferred)

## Demo Video/GIF

![demo](img/demo.gif)

## Methodology

### Naive Rendering
Naive rendering is the simplest approach to real-time rendering. In this method, each object in the scene is rendered independently, and every light source is applied to each fragment (pixel) of each object. This brute-force approach has significant limitations, especially as the number of lights in a scene increases, since every light must be tested against every pixel.

In our implementation, we began by creating a buffer that holds the view projection matrix, which allows us to transform objects from world space into camera space. This matrix is essential for computing where objects should be drawn relative to the camera. Although this method is straightforward, it quickly becomes inefficient in scenes with many lights or complex lighting effects because every fragment is processed multiple times for every light.

### Forward+ Rendering
Forward+ rendering builds on the traditional forward rendering method but improves efficiency by spatially clustering lights in a scene and applying only relevant lights to each fragment. In a typical forward renderer, all lights are tested against every fragment, leading to significant overhead in complex scenes. Forward+ addresses this by dividing the screen into clusters and determining which lights affect each cluster.

In our implementation, we created a data structure that divides the view frustum into clusters, and for each cluster, we track the lights that influence it. During rendering, we limit the lighting calculations for each fragment to only the lights that overlap its cluster, greatly reducing unnecessary computations. This approach strikes a balance between efficiency and flexibility by handling dynamic lighting in a way that scales better with the number of lights, especially for scenes with hundreds of light sources.

One important thing to note that is that we divide the z-dimensio or depth **exponentially**. This means that the clusters expand according to their area depth wise as we go farther out. This allows us to maintain high visual fidelity in the forefront while areas with a smaller amount of pixels in the background can be treated more as a group.

### Clustered Deferred Rendering
Clustered Deferred rendering further optimizes the process by separating the lighting calculations from the geometry rendering. This method builds on Forward+ by clustering the scene into regions, but instead of applying lights directly during the geometry pass, it defers lighting to a separate pass. In the first pass, all geometric information (such as normals, positions, and material properties) is stored in multiple render targets called a G-buffer. This G-buffer holds the necessary information to later apply lighting in a second, fullscreen pass.

The advantage of this method is that we only need to compute lighting once per pixel, instead of once per light per pixel. Since the geometry and lighting are handled in separate passes, Clustered Deferred rendering excels in scenes with high numbers of lights, as the lighting calculations are decoupled from the complexity of the geometry.

In our implementation, we reused the clustering logic from Forward+, which allows us to efficiently divide the scene into clusters. The G-buffer stores all the necessary information during the geometry pass, and in the second pass, we use the lights that affect each cluster to compute the final color for each pixel. This approach scales well with both geometry and lighting complexity, making it a powerful method for real-time rendering with many dynamic light sources.

*DO NOT* leave the README to the last minute! It is a crucial part of the
project, and we will not be able to grade you without a good README.

This assignment has a considerable amount of performance analysis compared
to implementation work. Complete the implementation early to leave time!

## Performance Analysis

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
