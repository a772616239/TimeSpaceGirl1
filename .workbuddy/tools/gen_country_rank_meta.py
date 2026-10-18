#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
为 CountryRankPanelAtlas 下的贴图生成 Unity .meta（照抄仓库现有 sprite meta 模板）：
  - textureType: 8（Sprite）、spriteMode: 1（Single）
  - spritePackingTag: CountryRankPanelAtlas（走 Unity 旧版图集打包）
  - 平台压缩：Android/iPhone ETC2(RGBA32)，Standalone RGBA32
  - guid 由文件名稳定派生（重复生成不会漂移）

同时写目录 .meta（assetBundleName = lz4/atlas/countryrankpanelatlas）。
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ATLAS_DIR = os.path.join(ROOT, "Assets/ManagedResources/Atlas/CountryRankPanelAtlas")
ATLAS_NAME = "CountryRankPanelAtlas"
AB_NAME = "lz4/atlas/countryrankpanelatlas"

TEMPLATE = """fileFormatVersion: 2
guid: {guid}
TextureImporter:
  internalIDToNameTable: []
  externalObjects: {{}}
  serializedVersion: 11
  mipmaps:
    mipMapMode: 0
    enableMipMap: 0
    sRGBTexture: 1
    linearTexture: 0
    fadeOut: 0
    borderMipMap: 0
    mipMapsPreserveCoverage: 0
    alphaTestReferenceValue: 0.5
    mipMapFadeDistanceStart: 1
    mipMapFadeDistanceEnd: 3
  bumpmap:
    convertToNormalMap: 0
    externalNormalMap: 0
    heightScale: 0.25
    normalMapFilter: 0
  isReadable: 0
  streamingMipmaps: 0
  streamingMipmapsPriority: 0
  grayScaleToAlpha: 0
  generateCubemap: 6
  cubemapConvolution: 0
  seamlessCubemap: 0
  textureFormat: 1
  maxTextureSize: 2048
  textureSettings:
    serializedVersion: 2
    filterMode: 2
    aniso: 1
    mipBias: 0
    wrapU: 1
    wrapV: 1
    wrapW: 1
  nPOTScale: 0
  lightmap: 0
  compressionQuality: 50
  spriteMode: 1
  spriteExtrude: 1
  spriteMeshType: 1
  alignment: 0
  spritePivot: {{x: 0.5, y: 0.5}}
  spritePixelsToUnits: 100
  spriteBorder: {{x: 0, y: 0, z: 0, w: 0}}
  spriteGenerateFallbackPhysicsShape: 1
  alphaUsage: 1
  alphaIsTransparency: 1
  spriteTessellationDetail: -1
  textureType: 8
  textureShape: 1
  singleChannelComponent: 0
  maxTextureSizeSet: 0
  compressionQualitySet: 0
  textureFormatSet: 0
  applyGammaDecoding: 1
  platformSettings:
  - serializedVersion: 3
    buildTarget: Android
    maxTextureSize: 2048
    resizeAlgorithm: 0
    textureFormat: 65
    textureCompression: 1
    compressionQuality: 50
    crunchedCompression: 0
    allowsAlphaSplitting: 0
    overridden: 1
    androidETC2FallbackOverride: 0
    forceMaximumCompressionQuality_BC6H_BC7: 1
  - serializedVersion: 3
    buildTarget: iPhone
    maxTextureSize: 2048
    resizeAlgorithm: 0
    textureFormat: 65
    textureCompression: 1
    compressionQuality: 50
    crunchedCompression: 0
    allowsAlphaSplitting: 0
    overridden: 1
    androidETC2FallbackOverride: 0
    forceMaximumCompressionQuality_BC6H_BC7: 1
  - serializedVersion: 3
    buildTarget: Standalone
    maxTextureSize: 2048
    resizeAlgorithm: 0
    textureFormat: 4
    textureCompression: 1
    compressionQuality: 50
    crunchedCompression: 0
    allowsAlphaSplitting: 0
    overridden: 1
    androidETC2FallbackOverride: 0
    forceMaximumCompressionQuality_BC6H_BC7: 1
  - serializedVersion: 3
    buildTarget: DefaultTexturePlatform
    maxTextureSize: 2048
    resizeAlgorithm: 0
    textureFormat: -1
    textureCompression: 1
    compressionQuality: 50
    crunchedCompression: 0
    allowsAlphaSplitting: 0
    overridden: 0
    androidETC2FallbackOverride: 0
    forceMaximumCompressionQuality_BC6H_BC7: 0
  spriteSheet:
    serializedVersion: 2
    sprites: []
    outline: []
    physicsShape: []
    bones: []
    spriteID: {sprite_id}
    internalID: 0
    vertices: []
    indices: 
    edges: []
    weights: []
    secondaryTextures: []
  spritePackingTag: {packing_tag}
  pSDRemoveMatte: 0
  pSDShowRemoveMatteOption: 0
  userData: 
  assetBundleName: 
  assetBundleVariant: 
"""

FOLDER_TEMPLATE = """fileFormatVersion: 2
guid: {guid}
folderAsset: yes
DefaultImporter:
  externalObjects: {{}}
  userData: 
  assetBundleName: {ab}
  assetBundleVariant: unity3d
"""


def guid_of(name):
    h = hashlib.md5(("TimeSpaceGirl1/CountryRankAtlas/" + name).encode("utf-8")).hexdigest()
    return h


def main():
    assert os.path.isdir(ATLAS_DIR), ATLAS_DIR
    # 目录 meta
    folder_meta = ATLAS_DIR + ".meta"
    with open(folder_meta, "w", encoding="utf-8", newline="\n") as f:
        f.write(FOLDER_TEMPLATE.format(guid=guid_of("__folder__"), ab=AB_NAME))
    print("  %-52s %s" % ("CountryRankPanelAtlas.meta", AB_NAME))

    count = 0
    for fn in sorted(os.listdir(ATLAS_DIR)):
        if not fn.endswith(".png"):
            continue
        name = fn[:-4]
        meta_path = os.path.join(ATLAS_DIR, fn + ".meta")
        with open(meta_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(TEMPLATE.format(guid=guid_of(name),
                                    sprite_id=guid_of("spriteid/" + name),
                                    packing_tag=ATLAS_NAME))
        count += 1
    print("  贴图 meta：%d 个" % count)


if __name__ == "__main__":
    main()
