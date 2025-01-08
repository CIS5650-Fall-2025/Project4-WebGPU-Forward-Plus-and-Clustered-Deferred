// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

struct FragmentInput {
    @location(0) pos: vec4f,
    @location(1) alb: vec4f,
    @location(2) nor: vec4f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    // figure out in which cluster we are in
    let clipPlaneRatio = cameraUniforms.clipPlanes[1] / cameraUniforms.clipPlanes[0];
    
    let posClip = cameraUniforms.viewProjMat * vec4f(in.posWorld, 1);
    var posNDC = posClip.xyz / posClip.w;
    //var posNDC = posClip.xyz ;
    //posNDC.x = 0.5 * (posNDC.x + 1);
    //posNDC.y = 0.5 * (posNDC.y + 1);
    posNDC.z = clamp(posNDC.z, 0, 1);
    
    
    //let posNDC = dingens.xyz;

    let thingy = cameraUniforms.viewMat * vec4f(in.posWorld, 1);
    let slice = u32(log(-thingy.z) * f32(clusterSet.numClusters.z) / log(clipPlaneRatio) - f32(clusterSet.numClusters.z) * log(cameraUniforms.clipPlanes[0]) / log(clipPlaneRatio));

    let clusterPos = vec3u(
        u32(0.5 * (posNDC.x + 1) * f32(clusterSet.numClusters.x)),
        u32(0.5 * (posNDC.y + 1) * f32(clusterSet.numClusters.y)),
        //u32(f32(clusterSet.numClusters.z) * log(posNDC.z * (clipPlaneRatio - 1)) / log(clipPlaneRatio))
        slice
    );

    let clusterIdx = calculateClusterIdx(clusterPos, clusterSet.numClusters);

    let cluster = &clusterSet.clusters[clusterIdx];
    var totalLightContrib = vec3f(0, 0, 0);
    for (var i = 0u; i < (*cluster).numLights; i++) {
        let lightIdx = (*cluster).lightIndices[i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    let finalColor = albedo.rgb * totalLightContrib;
    return vec4f(finalColor, 1);
}