using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

public class SimpleShell : MonoBehaviour {
    public Mesh shellMesh;
    public Shader shellShader;
    public Shader shellBaseShader;

    public bool updateStatics = true;

    [Range(0.0f, 1.0f)]
    public float shellLength = 0.15f;

    [Range(0.01f, 3.0f)]
    public float distanceAttenuation = 1.0f;

    [Range(1.0f, 1000.0f)]
    public float density = 100.0f;

    [Range(0.0f, 1.0f)]
    public float noiseMin = 0.0f;

    [Range(0.0f, 1.0f)]
    public float noiseMax = 1.0f;

    [Range(0.0f, 10.0f)]
    public float thickness = 1.0f;

    [Range(0.0f, 1.0f)]
    public float curvature = 1.0f;

    [Range(0.0f, 1.0f)]
    public float stiffness = 1.0f;

    [Range(0.0f, 1.0f)]
    public float displacementStrength = 0.1f;

    public Color shellColor;
    public Color baseShellColor;
    
    [Range(1, 6)]
    public int strandCount = 1;
    [Range(1, 6)]
    public int strandComplexity = 1;
    [Range(0.0f, 0.1f)]
    public float randomOffsetPower = 0.0f;
    [Range(0.0f, 0.2f)]
    public float curlPower = 0.0f;
    [Range(0.0f, 0.1f)]
    public float curlSize = 0.0f;
    [Range(0.0f, 1.0f)]
    public float baseFurAlpha = 1.0f;
    [Range(0.0f, 10.0f)]
    public float furAlphaPower = 10.0f;
    [Range(0.0f, 1.0f)]
    public float alphaCutoff = 1.0f;
    [Range(0.0f, 5.0f)]
    public float occlusionAttenuation = 1.0f;
    [Range(0.0f, 1.0f)]
    public float occlusionBias = 0.0f;
    
    [Range(0.0f, 10.0f)]
    public float gravity = 10.0f;
    [Range(0.0f, 10.0f)]
    public float diffPower = 1.0f;
    [Range(0.0f, 10.0f)]
    public float windForce = 1.0f;
    [Range(0.0f, 10.0f)]
    public float windTurbulence = 1.0f;
    [Range(0.0f, 10.0f)]
    public float windNoiseFactor = 1.0f;
    [Range(0.0f, 10.0f)]
    public float windNoiseFactor2 = 1.0f;
    [Range(0.0f, 10.0f)]
    public float windNoiseAmplitude = 1.0f;
    public Transform windTransform;

    [Range(0.0f, 1.0f)]
    public float smoothness = 0.0f;
    [Range(0.0f, 1.0f)]
    public float metallic = 0.0f;
    [Range(0.0f, 1.0f)]
    public float occlusion = 0.0f;
    public Transform light;


    private Material shellMaterial;
    private Material shellBaseMaterial;
    private GameObject shell;
    private Mesh spawnedShellMesh;
    private GameObject shellBase;
    private int oldStrandCount = 1;
    private int oldStrandComplexity = 1;
    private Vector3[] positions;
    private Vector3[] normals;
    private Vector2[] directionsXY;
    private Vector2[] directionsZ;
    private Vector3[] targetDirections;
    private Vector3[] velocities;
    private Vector3 oldEulers;
    private Vector3 oldPos;
    private float angleZ;
    private float angleX;
    private float windT = 0.0f;

    private Vector3 displacementDirection = new Vector3(0, 0, 0);


    private void OnValidate()
    {
        if(strandCount != oldStrandCount || strandComplexity != oldStrandComplexity)
        {
            int overallCount = strandCount + strandComplexity;
            if (overallCount > 6)
            {
                if(strandCount != oldStrandCount)
                {
                    strandComplexity = 7 - strandCount;
                }
                if (strandComplexity != oldStrandComplexity)
                {
                    strandCount = 7 - strandComplexity;
                }
            }
            oldStrandComplexity = strandComplexity;
            oldStrandCount = strandCount;
        }
    }
    void OnEnable() {
        shellMaterial = new Material(shellShader);
        shellBaseMaterial = new Material(shellBaseShader);


        shell = new GameObject("Shell");
        //shellBase = new GameObject("ShellBase");
        //MeshRenderer baseRenderer = shellBase.AddComponent<MeshRenderer>();
        MeshRenderer renderer = shell.AddComponent<MeshRenderer>();
        MeshFilter filter = shell.AddComponent<MeshFilter>();
        //MeshFilter baseFilter = shellBase.AddComponent<MeshFilter>();
        filter.mesh = shellMesh;
        spawnedShellMesh = filter.mesh;
        //baseFilter.mesh = shellMesh;
        renderer.material = shellMaterial;
        //baseRenderer.material = shellBaseMaterial;
        //shellBase.transform.SetParent(this.transform, false);
        shell.transform.SetParent(this.transform, false);
        shellMaterial.SetFloat("_ShellLength", shellLength);
        shellMaterial.SetFloat("_Density", density);
        shellMaterial.SetFloat("_Thickness", thickness);
        shellMaterial.SetFloat("_ShellDistanceAttenuation", distanceAttenuation);
        shellMaterial.SetFloat("_Curvature", curvature);
        shellMaterial.SetFloat("_Stiffness", stiffness);
        shellMaterial.SetFloat("_DisplacementStrength", displacementStrength);
        shellMaterial.SetFloat("_NoiseMin", noiseMin);
        shellMaterial.SetFloat("_NoiseMax", noiseMax);
        shellMaterial.SetVector("_ShellColor", shellColor);
        shellMaterial.SetFloat("_StrandFactor", Mathf.Pow(2.0f, strandCount + strandComplexity - 1.0f));
        shellMaterial.SetFloat("_StrandCount", Mathf.Pow(2.0f, strandCount));
        shellMaterial.SetFloat("_RandomOffsetPower", randomOffsetPower);
        shellMaterial.SetFloat("_CurlPower", curlPower);
        shellMaterial.SetFloat("_CurlSize", curlSize);
        shellMaterial.SetVector("_ShellDirection", displacementDirection);
        shellMaterial.SetFloat("_AlphaBase", baseFurAlpha);
        shellMaterial.SetFloat("_AlphaPower", furAlphaPower);
        shellMaterial.SetFloat("_AlphaCutoff", alphaCutoff);
        shellMaterial.SetFloat("_Attenuation", occlusionAttenuation);
        shellMaterial.SetFloat("_OcclusionBias", occlusionBias);
        shellMaterial.SetFloat("_Attenuation", occlusionAttenuation);
        shellMaterial.SetFloat("_Smoothness", smoothness);
        shellMaterial.SetFloat("_Metallic", metallic);
        shellMaterial.SetFloat("_Occlusion", occlusion);

        shellMaterial.SetVector("_LightDir", -light.forward);
        //shellBaseMaterial.color = baseShellColor;

        Vector3[] tempNormals = spawnedShellMesh.normals;
        positions = spawnedShellMesh.vertices;
        normals = new Vector3[tempNormals.Length];
        directionsXY = new Vector2[tempNormals.Length];
        directionsZ = new Vector2[tempNormals.Length];
        velocities = new Vector3[tempNormals.Length];
        targetDirections = new Vector3[tempNormals.Length];
        oldEulers = shell.transform.eulerAngles;
        for (int i = 0; i < tempNormals.Length; ++i)
        {
            normals[i] = tempNormals[i];
            directionsXY[i] = new Vector2(tempNormals[i].x, tempNormals[i].y);
            directionsZ[i] = new Vector2(tempNormals[i].z, 0.0f);
            targetDirections[i] = tempNormals[i];
            velocities[i] = Vector3.zero;
        }
    }

    void Update() {
        float velocity = 1.0f;
        float rotVelocity = 90.0f;

        Vector3 direction = new Vector3(0, 0, 0);
        Vector3 oppositeDirection = new Vector3(0, 0, 0);
        float rotAngleZ = 0.0f;
        float rotAngleX = 0.0f;

        // This determines the direction we are moving from wasd input. It's probably a better idea to use Unity's input system, since it handles
        // all possible input devices at once, but I did it the old fashioned way for simplicity.
        direction.x = Convert.ToInt32(Input.GetKey(KeyCode.D)) - Convert.ToInt32(Input.GetKey(KeyCode.A));
        direction.y = Convert.ToInt32(Input.GetKey(KeyCode.W)) - Convert.ToInt32(Input.GetKey(KeyCode.S));
        direction.z = Convert.ToInt32(Input.GetKey(KeyCode.Q)) - Convert.ToInt32(Input.GetKey(KeyCode.E));
        rotAngleZ = Convert.ToInt32(Input.GetKey(KeyCode.J)) - Convert.ToInt32(Input.GetKey(KeyCode.L));
        rotAngleX = Convert.ToInt32(Input.GetKey(KeyCode.I)) - Convert.ToInt32(Input.GetKey(KeyCode.K));

        // This moves the ball according the input direction
        Vector3 currentPosition = this.transform.position;
        Vector3 currentEulers = this.transform.rotation.eulerAngles;
        direction.Normalize();
        currentPosition += direction * velocity * Time.deltaTime;
        this.transform.position = currentPosition;
        angleZ = rotVelocity * rotAngleZ * Time.deltaTime;
        angleX = rotVelocity * rotAngleX * Time.deltaTime;
        Quaternion newRot = Quaternion.Euler(angleX, 0, angleZ);
        this.transform.rotation = this.transform.rotation*newRot;


        // This changes the direction that the hair is going to point in, when we are not inputting any movements then we subtract the gravity vector
        // The gravity vector just being (0, -1, 0)
        displacementDirection -= direction * Time.deltaTime * 10.0f;
        if (direction == Vector3.zero)
            displacementDirection.y -= gravity * Time.deltaTime;

        if (displacementDirection.magnitude > 1) displacementDirection = displacementDirection.normalized;

        // In order to avoid setting this variable on every single shell's material instance, we instead set this is as a global shader variable
        // That every shader will have access to, which sounds bad, because it kind of is, but just be aware of your global variable names and it's not a big deal.
        // Regardless, setting the variable one time instead of 256 times is just better.

        // Generally it is bad practice to update statics that do not need to be updated every frame
        // You can see the performance difference between updating 256 shells of statics by disabling the updateStatics parameter in the script
        // So it obviously matters at the extreme ends, but something above like setting the directional vector each frame is not going to make an insane diff
        // You will see in my other shaders and scripts that I do not always do this, because I'm lazy, but it's best practice to not update what doesn't need to be
        // updated.
        if (updateStatics) {
            shellMaterial.SetFloat("_ShellLength", shellLength);
            shellMaterial.SetFloat("_Density", density);
            shellMaterial.SetFloat("_Thickness", thickness);
            shellMaterial.SetFloat("_ShellDistanceAttenuation", distanceAttenuation);
            shellMaterial.SetFloat("_Curvature", curvature);
            shellMaterial.SetFloat("_Stiffness", stiffness);
            shellMaterial.SetFloat("_DisplacementStrength", displacementStrength);
            shellMaterial.SetFloat("_NoiseMin", noiseMin);
            shellMaterial.SetFloat("_NoiseMax", noiseMax);
            shellMaterial.SetVector("_ShellColor", shellColor);
            shellMaterial.SetFloat("_StrandFactor", Mathf.Pow(2.0f, strandCount + strandComplexity - 1.0f));
            shellMaterial.SetFloat("_StrandCount", Mathf.Pow(2.0f, strandCount));
            shellMaterial.SetFloat("_RandomOffsetPower", randomOffsetPower);
            shellMaterial.SetFloat("_CurlPower", curlPower);
            shellMaterial.SetFloat("_CurlSize", curlSize);
            shellMaterial.SetFloat("_AlphaBase", baseFurAlpha);
            shellMaterial.SetFloat("_AlphaPower", furAlphaPower);
            shellMaterial.SetVector("_ShellDirection", displacementDirection);
            shellMaterial.SetFloat("_AlphaCutoff", alphaCutoff);
            shellMaterial.SetFloat("_Attenuation", occlusionAttenuation);
            shellMaterial.SetFloat("_OcclusionBias", occlusionBias);
            shellMaterial.SetVector("_LightDir", -light.forward);
            shellMaterial.SetFloat("_Smoothness", smoothness);
            shellMaterial.SetFloat("_Metallic", metallic);
            shellMaterial.SetFloat("_Occlusion", occlusion);
            //shellBaseMaterial.color = baseShellColor;
        }

        Transform meshTransform = shell.transform;
        Vector3 posDelta = meshTransform.position - oldPos;
        Vector3 eulerDelta = meshTransform.eulerAngles - oldEulers;
        Quaternion deltaRotation = Quaternion.Euler(eulerDelta);
        Vector3 windDirection = windTransform.forward;
        windT += Time.deltaTime;
        for (int directionIndex = 0; directionIndex < normals.Length; ++directionIndex)
        {
            float distRelativeToWind = Vector3.Dot(meshTransform.TransformPoint(positions[directionIndex]), windDirection);
            float distLateralToWind = Vector3.Cross(meshTransform.TransformPoint(positions[directionIndex]), windDirection).magnitude;

            Vector3 surfaceNormal = normals[directionIndex];
            surfaceNormal = meshTransform.TransformDirection(surfaceNormal);
            float dotDown = Vector3.Dot(surfaceNormal, Vector3.down);
            Vector3 newTarget = (dotDown >= 0.0f) ? Vector3.down : Vector3.down - dotDown * surfaceNormal;
            targetDirections[directionIndex] = newTarget.normalized;


            Vector3 dir = new Vector3(directionsXY[directionIndex].x, directionsXY[directionIndex].y, directionsZ[directionIndex].x);
            Vector3 deltaRotatedDir = deltaRotation * dir;
            //dir = Vector3.Slerp(dir, targetDirections[directionIndex], gravity*Time.deltaTime);
            Vector3 diff = diffPower*(targetDirections[directionIndex] - deltaRotatedDir - (posDelta / Time.deltaTime)) + windForce*windDirection*(0.5f*Mathf.Cos(distRelativeToWind + Mathf.PerlinNoise(distRelativeToWind* windNoiseFactor, distLateralToWind * windNoiseFactor2) *windNoiseAmplitude + windTurbulence*windT) + 0.5f);


            Vector3 dirNewOffset = velocities[directionIndex]*Time.deltaTime + gravity*0.5f*diff*Time.deltaTime*Time.deltaTime;

            velocities[directionIndex] += gravity * diff * Time.deltaTime;

            dir = (dir + dirNewOffset);
            if(dir.magnitude > 1.0f)
            {
                dir = dir.normalized;
                velocities[directionIndex] = velocities[directionIndex] - Vector3.Dot(velocities[directionIndex], dir)*dir;
            }

            float controlDot = Vector3.Dot(dir, surfaceNormal);
            if(controlDot < 0.0f)
            {
                dir = dir - controlDot * surfaceNormal;
                velocities[directionIndex] = Vector3.zero;
            }
            directionsXY[directionIndex] = new Vector2(dir.x, dir.y);
            directionsZ[directionIndex] = new Vector2(dir.z, 0.0f);

        }
        
        spawnedShellMesh.uv2 = directionsXY;
        spawnedShellMesh.uv3 = directionsZ;
        oldEulers = meshTransform.eulerAngles;
        oldPos = meshTransform.position;
    }

    void OnDisable() {
        Destroy(shell);

        shell = null;
    }
}
