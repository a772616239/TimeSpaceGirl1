using UnityEditor;
using UnityEngine;

namespace TimeSpaceGirl.EditorTools
{
    /// <summary>
    /// Keeps MCP for Unity on the stdio transport and boots its stdio bridge for
    /// this machine. Two reasons this exists:
    /// 1. Jenkins already owns 127.0.0.1:8080, so the package's HTTP/WebSocket
    ///    transport can never start here; its auto-config switching to HTTP
    ///    therefore kills the stdio bridge AND fails to start HTTP, leaving
    ///    MCP dead ("No Unity Editor instances found").
    /// 2. The stdio bridge normally only auto-boots when UseHttpTransport=false,
    ///    and package re-imports can silently flip that pref back to HTTP.
    /// Idempotent: the CI boot helper pins stdio for the session and no-ops when
    /// the bridge is already running.
    /// </summary>
    [InitializeOnLoad]
    internal static class McpBridgeBoot
    {
        static McpBridgeBoot()
        {
            if (Application.isBatchMode &&
                string.IsNullOrWhiteSpace(System.Environment.GetEnvironmentVariable("UNITY_MCP_ALLOW_BATCH")))
            {
                return; // same guard as the package: never boot MCP inside CI/headless builds
            }

            EditorApplication.delayCall += Boot;
        }

        private static void Boot()
        {
            MCPForUnity.Editor.McpCiBoot.StartStdioForCi();
            UnityEngine.Debug.Log("[McpBridgeBoot] stdio bridge boot requested (Jenkins owns 8080; HTTP not viable).");
        }
    }
}
