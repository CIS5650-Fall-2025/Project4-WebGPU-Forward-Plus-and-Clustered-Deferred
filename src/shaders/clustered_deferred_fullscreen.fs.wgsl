// TODO-3: implement the Clustered Deferred fullscreen fragment shader

struct FragmentInput {
    @location(0) fragUV: vec2<f32>,
};

@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> lightSet: LightSet;
@group(0) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;
@group(${bindGroup_material}) @binding(2) var gNormalTexture: texture_2d<f32>;
@group(${bindGroup_material}) @binding(3) var gDepthTexture: texture_2d<f32>;
@group(${bindGroup_material}) @binding(4) var depthSampler: sampler_comparison;

@fragment
fn main(input: FragmentInput) -> @location(0) vec4<f32> {
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, input.fragUV);
    let normal = textureSample(gNormalTexture, diffuseTexSampler, input.fragUV).xyz;
    let depth = textureSample(gDepthTexture, depthSampler, input.fragUV).r;

    // Reconstruct world position from depth
    let clipSpacePosition = vec4<f32>(input.fragUV * 2.0 - 1.0, depth, 1.0);
    let worldPosition = (cameraUniforms.invViewProjMat * clipSpacePosition).xyz;

    // Determine which cluster this fragment belongs to
    let ndc = clipSpacePosition.xyz / clipSpacePosition.w;
    let ndcXY01 = ndc.xy * 0.5 + 0.5;
    let epsilon = 0.0001;
    let ndcX = clamp(ndcXY01.x, 0.0, 1.0 - epsilon);
    let ndcY = clamp(ndcXY01.y, 0.0, 1.0 - epsilon);
    let clusterX = u32(floor(ndcX * f32(clusterSet.numClustersX)));
    let clusterY = u32(floor(ndcY * f32(clusterSet.numClustersY)));

    let viewPos = cameraUniforms.viewMat * vec4(worldPosition, 1.0);
    let viewZ = viewPos.z; 
    let zNear = cameraUniforms.nearPlane;
    let zFar = cameraUniforms.farPlane;
    let sliceCount = clusterSet.numClustersZ;
    let logDepthRatio = log(zFar / zNear);
    let viewZClamped = clamp(-viewZ, zNear, zFar); 

    let clusterZf = (log(viewZClamped / zNear) / logDepthRatio) * f32(sliceCount);
    var clusterZ = u32(floor(clusterZf));
    clusterZ = clamp(clusterZ, 0u, clusterSet.numClustersZ - 1u);

    var clusterIndex = clusterX + 
                       clusterY * clusterSet.numClustersX + 
                       clusterZ * clusterSet.numClustersX * clusterSet.numClustersY;

    let maxClusterIndex = clusterSet.numClustersX * clusterSet.numClustersY * clusterSet.numClustersZ - 1u;
    clusterIndex = clamp(clusterIndex, 0, maxClusterIndex);
    let cluster = clusterSet.clusters[clusterIndex];

    // Perform lighting calculations
    var totalLightContrib = vec3f(0.0, 0.0, 0.0);
    for (var i = 0u; i < cluster.lightCount; i++) {
        let lightIndex = cluster.lightIndices[i];
        let light = lightSet.lights[lightIndex];
        totalLightContrib += calculateLightContrib(light, worldPosition, normal);
    }

    let finalColor = diffuseColor.rgb * totalLightContrib;
    //let finalColor = vec3(0.5);
    return vec4(finalColor, 1.0);
}