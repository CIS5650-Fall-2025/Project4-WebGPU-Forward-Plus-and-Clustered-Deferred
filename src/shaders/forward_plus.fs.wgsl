// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput {
    @location(0) pos: vec3<f32>,
    @location(1) nor: vec3<f32>,
    @location(2) uv: vec2<f32>,
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4<f32> {
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5) {
        discard;
    }

    let clusterGridSize = camera.clusterGridSize;
    let clipPos = camera.viewProjMat * vec4<f32>(in.pos, 1.0);

 
    if (clipPos.w == 0.0) {
        discard;
    }


    let ndcPos = clipPos.xyz / clipPos.w;

    let ndcPos01 = ndcPos * 0.5 + vec3<f32>(0.5);

 
    //let ndcPosClamped = clamp(ndcPos01, vec3<f32>(0.0), vec3<f32>(1.0));

  
    let clusterX = u32(ndcPos01.x * f32(clusterGridSize.x));
    let clusterY = u32(ndcPos01.y * f32(clusterGridSize.y));
    let clusterZ = u32(ndcPos01.z * f32(clusterGridSize.z));
    // let viewZ = (in.pos.z - camera.nearPlane)/(camera.farPlane - camera.nearPlane);
    // let clusterZ = u32(viewZ * f32(clusterGridSize.z));
   
    let clusterXClamped = min(clusterX, clusterGridSize.x - 1u);
    let clusterYClamped = min(clusterY, clusterGridSize.y - 1u);
    let clusterZClamped = min(clusterZ, clusterGridSize.z - 1u);

    
    let clusterIndex = clusterZClamped * clusterGridSize.x * clusterGridSize.y +
                       clusterYClamped * clusterGridSize.x +
                       clusterXClamped;

    
    

    
    

    var totalLightContrib = vec3<f32>(0.0, 0.0, 0.0);
    var finalColor = vec3<f32>(1.0, 1.0, 1.0);
    if (clusterSet.clusters[clusterIndex].numLights > 0){
        finalColor = vec3<f32>(1.0, 0.0, 1.0);
        return vec4<f32>(finalColor, 1.0);
    }
    
    // for (var i = 0u; i < clusterSet.clusters[clusterIndex].numLights; i++) {
        
    //     let lightIdx = clusterSet.clusters[clusterIndex].lightIndices[i];
        
    //     let light = lightSet.lights[lightIdx];
    //     totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
        
    // }
    
    return vec4<f32>(finalColor, 1.0);
    
}