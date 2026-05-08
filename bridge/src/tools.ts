/**
 * MCP tool definitions and handlers for the MOHO bridge.
 *
 * Each tool maps 1-to-1 to a JSON-RPC method exposed by the MOHO Lua server.
 */

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { MohoClient } from "./moho-client.js";
import { config } from "./config.js";
import { captureAppWindow } from "./platform-capture.js";
import { sendMouseClick, sendMouseDrag, sendKeys } from "./platform-input.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Formats a successful MOHO result as MCP text content.
 */
function successContent(result: unknown): { content: Array<{ type: "text"; text: string }> } {
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify(result, null, 2),
      },
    ],
  };
}

/**
 * Formats an error as an MCP error response.
 */
function errorContent(err: unknown): {
  content: Array<{ type: "text"; text: string }>;
  isError: true;
} {
  const message = err instanceof Error ? err.message : String(err);
  return {
    content: [
      {
        type: "text" as const,
        text: message,
      },
    ],
    isError: true,
  };
}

/**
 * Ensures the client is connected before making a request.
 * If not connected, attempts to connect first.
 */
async function ensureConnected(client: MohoClient): Promise<void> {
  if (!client.isConnected()) {
    await client.connect();
  }
}

// ---------------------------------------------------------------------------
// Tool registration
// ---------------------------------------------------------------------------

/**
 * Register all MOHO tools on the given MCP server instance.
 */
export function registerTools(server: McpServer, client: MohoClient): void {
  // 1. document.getInfo — No input params
  server.tool(
    "document_getInfo",
    "Get information about the currently open MOHO document (name, path, dimensions, frame range, FPS)",
    {},
    async () => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("document.getInfo");
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 2. document.getLayers — No input params
  server.tool(
    "document_getLayers",
    "Get a list of all top-level layers in the current MOHO document",
    {},
    async () => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("document.getLayers");
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 3. layer.getProperties — layerId required
  server.tool(
    "layer_getProperties",
    "Get detailed properties of a specific layer (type, visibility, transform, etc.)",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.getProperties", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 4. layer.getChildren — layerId required
  server.tool(
    "layer_getChildren",
    "Get child layers of a group layer",
    {
      layerId: z.number().describe("The numeric ID of the parent group layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.getChildren", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 5. layer.getBones — layerId required
  server.tool(
    "layer_getBones",
    "Get all bones in a bone layer",
    {
      layerId: z.number().describe("The numeric ID of the bone layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.getBones", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 6. bone.getProperties — layerId and boneId required
  server.tool(
    "bone_getProperties",
    "Get detailed properties of a specific bone (position, angle, scale, parent, etc.)",
    {
      layerId: z.number().describe("The numeric ID of the bone layer"),
      boneId: z.number().describe("The numeric ID of the bone within the layer"),
    },
    async ({ layerId, boneId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("bone.getProperties", {
          layerId,
          boneId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 7. animation.getKeyframes — layerId and channel required
  server.tool(
    "animation_getKeyframes",
    "Get keyframe data for a specific animation channel on a layer",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      channel: z
        .string()
        .describe(
          'The animation channel name (e.g. "translation", "rotation", "scale", "opacity")',
        ),
    },
    async ({ layerId, channel }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("animation.getKeyframes", {
          layerId,
          channel,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 8. animation.getFrameState — layerId and frame required
  server.tool(
    "animation_getFrameState",
    "Get the full animation state of a layer at a specific frame",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      frame: z.number().describe("The frame number to query"),
    },
    async ({ layerId, frame }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("animation.getFrameState", {
          layerId,
          frame,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 9. mesh.getPoints — layerId required
  server.tool(
    "mesh_getPoints",
    "Get all mesh points (vertices) in a vector layer",
    {
      layerId: z.number().describe("The numeric ID of the vector layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("mesh.getPoints", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 10. mesh.getShapes — layerId required
  server.tool(
    "mesh_getShapes",
    "Get all shapes (filled regions) in a vector layer",
    {
      layerId: z.number().describe("The numeric ID of the vector layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("mesh.getShapes", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Phase 2: Write Tools
  // =========================================================================

  // 11. bone.setTransform — Pose a bone at a frame
  server.tool(
    "bone_setTransform",
    "Set the transform (angle, position, scale) of a bone at a specific frame. Creates keyframes automatically. All transform params (angle, posX, posY, scale) are optional — only supplied values are changed.",
    {
      layerId: z.number().describe("The numeric ID of the bone layer"),
      boneId: z.number().describe("The 0-based bone index within the skeleton"),
      frame: z.number().describe("The frame number to set the keyframe at"),
      angle: z
        .number()
        .optional()
        .describe("Bone rotation in radians"),
      posX: z
        .number()
        .optional()
        .describe("Bone X position"),
      posY: z
        .number()
        .optional()
        .describe("Bone Y position"),
      scale: z
        .number()
        .optional()
        .describe("Bone scale factor"),
    },
    async ({ layerId, boneId, frame, angle, posX, posY, scale }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("bone.setTransform", {
          layerId,
          boneId,
          frame,
          angle,
          posX,
          posY,
          scale,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 12. bone.selectBone — Select a bone in the UI
  server.tool(
    "bone_selectBone",
    "Select a bone in the MOHO UI (deselects all others first)",
    {
      layerId: z.number().describe("The numeric ID of the bone layer"),
      boneId: z.number().describe("The 0-based bone index within the skeleton"),
    },
    async ({ layerId, boneId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("bone.selectBone", {
          layerId,
          boneId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 13. animation.setKeyframe — Set a keyframe value on any animation channel
  server.tool(
    "animation_setKeyframe",
    "Set a keyframe value on an animation channel. For vec2 channels (translation, scale), pass value as {x, y}. For scalar channels (rotation, opacity, shear), pass a number.",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      channel: z
        .string()
        .describe(
          'The animation channel name (e.g. "translation", "rotation", "scale", "opacity", "shear")',
        ),
      frame: z.number().describe("The frame number to set the keyframe at"),
      value: z
        .union([z.number(), z.object({ x: z.number(), y: z.number() })])
        .describe("The keyframe value — number for scalar channels, {x, y} for vec2 channels"),
    },
    async ({ layerId, channel, frame, value }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("animation.setKeyframe", {
          layerId,
          channel,
          frame,
          value,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 14. animation.deleteKeyframe — Remove a keyframe
  server.tool(
    "animation_deleteKeyframe",
    "Delete a keyframe from an animation channel at a specific frame",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      channel: z
        .string()
        .describe(
          'The animation channel name (e.g. "translation", "rotation", "scale", "opacity")',
        ),
      frame: z.number().describe("The frame number of the keyframe to delete"),
    },
    async ({ layerId, channel, frame }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("animation.deleteKeyframe", {
          layerId,
          channel,
          frame,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 15. animation.setInterpolation — Set easing mode on a keyframe
  server.tool(
    "animation_setInterpolation",
    "Set the interpolation/easing mode on an existing keyframe (linear, smooth, ease_in, ease_out, step)",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      channel: z
        .string()
        .describe(
          'The animation channel name (e.g. "translation", "rotation", "scale", "opacity")',
        ),
      frame: z.number().describe("The frame number of the keyframe"),
      mode: z
        .string()
        .describe(
          'Interpolation mode: "linear", "smooth", "ease_in", "ease_out", or "step"',
        ),
    },
    async ({ layerId, channel, frame, mode }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("animation.setInterpolation", {
          layerId,
          channel,
          frame,
          mode,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 16. document.setFrame — Navigate to a specific frame
  server.tool(
    "document_setFrame",
    "Navigate to a specific frame on the MOHO timeline",
    {
      frame: z.number().describe("The frame number to navigate to"),
    },
    async ({ frame }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("document.setFrame", {
          frame,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 17. layer.setTransform — Move/rotate/scale a layer at a frame
  server.tool(
    "layer_setTransform",
    "Set the transform (translation, rotation, scale) of a layer at a specific frame. All transform params are optional — only supplied values are changed. Translation and scale are 3D channels (AnimVec3); transZ/scaleZ default to the existing z value when omitted.",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      frame: z.number().describe("The frame number to set the keyframe at"),
      transX: z.number().optional().describe("Layer X translation"),
      transY: z.number().optional().describe("Layer Y translation"),
      transZ: z.number().optional().describe("Layer Z translation"),
      rotation: z
        .number()
        .optional()
        .describe("Layer rotation in radians (Z axis)"),
      scaleX: z.number().optional().describe("Layer X scale"),
      scaleY: z.number().optional().describe("Layer Y scale"),
      scaleZ: z.number().optional().describe("Layer Z scale"),
    },
    async ({ layerId, frame, transX, transY, transZ, rotation, scaleX, scaleY, scaleZ }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setTransform", {
          layerId,
          frame,
          transX,
          transY,
          transZ,
          rotation,
          scaleX,
          scaleY,
          scaleZ,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 18. layer.setVisibility — Show/hide a layer
  server.tool(
    "layer_setVisibility",
    "Show or hide a layer in the MOHO scene",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      visible: z.boolean().describe("Whether the layer should be visible"),
    },
    async ({ layerId, visible }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setVisibility", {
          layerId,
          visible,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 19. layer.setOpacity — Set layer transparency at a frame
  server.tool(
    "layer_setOpacity",
    "Set the opacity/transparency of a layer at a specific frame (0.0 = fully transparent, 1.0 = fully opaque)",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      frame: z.number().describe("The frame number to set the keyframe at"),
      opacity: z.number().describe("Opacity value from 0.0 (transparent) to 1.0 (opaque)"),
    },
    async ({ layerId, frame, opacity }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setOpacity", {
          layerId,
          frame,
          opacity,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 20. layer.setName — Rename a layer
  server.tool(
    "layer_setName",
    "Rename a layer in the MOHO scene",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      name: z.string().describe("The new name for the layer"),
    },
    async ({ layerId, name }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setName", {
          layerId,
          name,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 21. layer.selectLayer — Select a layer in the UI
  server.tool(
    "layer_selectLayer",
    "Select a layer in the MOHO UI",
    {
      layerId: z.number().describe("The numeric ID of the layer to select"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.selectLayer", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Phase 3: Visual Feedback
  // =========================================================================

  // 22. document.screenshot — Render the scene and return as an image
  server.tool(
    "document_screenshot",
    'Render the MOHO scene or capture the full application window and return as an image. Use mode "scene" (default) for a clean rendered frame, or "full" for the entire MOHO UI including timeline, layers panel, etc.',
    {
      mode: z
        .enum(["scene", "full"])
        .optional()
        .describe(
          '"scene" = rendered animation frame only (default), "full" = entire MOHO application window via native screen capture',
        ),
      frame: z
        .number()
        .optional()
        .describe("Frame number to render (defaults to current frame)"),
      width: z
        .number()
        .optional()
        .describe("Output width in pixels (defaults to document width, scene mode only)"),
      height: z
        .number()
        .optional()
        .describe("Output height in pixels (defaults to document height, scene mode only)"),
    },
    async ({ mode, frame, width, height }) => {
      try {
        const captureMode = mode ?? "scene";

        if (captureMode === "full") {
          // Navigate to requested frame first (via Lua), then Win32 capture
          if (frame !== undefined) {
            await ensureConnected(client);
            await client.sendRequest("document.setFrame", { frame });
          }

          const tempDir = path.join(os.tmpdir(), "moho-mcp");
          await fs.promises.mkdir(tempDir, { recursive: true });
          const tempPath = path.join(
            tempDir,
            `capture_${Date.now()}.png`,
          );

          const dims = await captureAppWindow(tempPath);

          const imageBuffer = await fs.promises.readFile(tempPath);
          const base64 = imageBuffer.toString("base64");
          await fs.promises.unlink(tempPath).catch(() => {});

          return {
            content: [
              {
                type: "image" as const,
                mimeType: "image/png" as const,
                data: base64,
              },
              {
                type: "text" as const,
                text: JSON.stringify({
                  mode: "full",
                  frame: frame ?? null,
                  width: dims.width,
                  height: dims.height,
                }),
              },
            ],
          };
        }

        // Scene mode — use MOHO's FileRender via Lua
        await ensureConnected(client);
        const params: Record<string, unknown> = {};
        if (frame !== undefined) params.frame = frame;
        if (width !== undefined) params.width = width;
        if (height !== undefined) params.height = height;

        const result = (await client.sendRequest(
          "document.screenshot",
          params,
          { timeout: config.moho.renderTimeout },
        )) as {
          success: boolean;
          filePath: string;
          frame: number;
          width: number;
          height: number;
        };

        // Read the rendered PNG from disk
        const imageBuffer = await fs.promises.readFile(result.filePath);
        const base64 = imageBuffer.toString("base64");

        // Clean up the temp file
        await fs.promises.unlink(result.filePath).catch(() => {});

        return {
          content: [
            {
              type: "image" as const,
              mimeType: "image/png" as const,
              data: base64,
            },
            {
              type: "text" as const,
              text: JSON.stringify({
                mode: "scene",
                frame: result.frame,
                width: result.width,
                height: result.height,
              }),
            },
          ],
        };
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Phase 3b: Input Tools (Mouse & Keyboard)
  // =========================================================================

  // 23. input.mouseClick — Click at a position in the MOHO window
  server.tool(
    "input_mouseClick",
    "Click at (x, y) coordinates relative to the MOHO window top-left. Use with document_screenshot(mode='full') to identify UI element positions, then click them.",
    {
      x: z.number().describe("X coordinate relative to MOHO window top-left"),
      y: z.number().describe("Y coordinate relative to MOHO window top-left"),
      button: z
        .enum(["left", "right", "middle"])
        .optional()
        .describe('Mouse button: "left" (default), "right", "middle"'),
      clickType: z
        .enum(["single", "double"])
        .optional()
        .describe('Click type: "single" (default), "double"'),
    },
    async ({ x, y, button, clickType }) => {
      try {
        const result = await sendMouseClick(
          x,
          y,
          button ?? "left",
          clickType ?? "single",
        );
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 24. input.mouseDrag — Drag from one point to another in the MOHO window
  server.tool(
    "input_mouseDrag",
    "Drag from (startX, startY) to (endX, endY) relative to the MOHO window. Useful for dragging timeline playhead, sliders, or drawing operations.",
    {
      startX: z.number().describe("Drag start X coordinate (window-relative)"),
      startY: z.number().describe("Drag start Y coordinate (window-relative)"),
      endX: z.number().describe("Drag end X coordinate (window-relative)"),
      endY: z.number().describe("Drag end Y coordinate (window-relative)"),
      button: z
        .enum(["left", "right"])
        .optional()
        .describe('Mouse button: "left" (default), "right"'),
      steps: z
        .number()
        .optional()
        .describe("Number of intermediate points for smooth drag (default 10)"),
    },
    async ({ startX, startY, endX, endY, button, steps }) => {
      try {
        const result = await sendMouseDrag(
          startX,
          startY,
          endX,
          endY,
          button ?? "left",
          steps ?? 10,
        );
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 25. input.sendKeys — Send keyboard shortcut to MOHO
  server.tool(
    "input_sendKeys",
    'Send a keyboard shortcut to the MOHO window. Supports modifiers (ctrl, shift, alt) combined with keys. Examples: "ctrl+z" (undo), "ctrl+shift+z" (redo), "space" (play/pause), "delete", "ctrl+s" (save), "f5".',
    {
      keys: z
        .string()
        .describe(
          'Shortcut string like "ctrl+z", "ctrl+shift+z", "space", "delete", "ctrl+s", "f5", "a"',
        ),
    },
    async ({ keys }) => {
      try {
        const result = await sendKeys(keys);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Batch Execution
  // =========================================================================

  // 26. batch.execute — Execute multiple operations in a single IPC round-trip
  server.tool(
    "batch_execute",
    "Execute multiple MOHO operations in a single IPC round-trip (~300ms total) instead of one round-trip per call (~300ms each). " +
      "PREFER THIS over individual calls whenever you have 2+ operations.\n\n" +
      "Method names use DOT notation: \"bone.setTransform\", \"layer.getProperties\", \"animation.setKeyframe\", etc. " +
      "Params match each tool's schema exactly.\n\n" +
      "Supports all methods EXCEPT: document.screenshot (too slow), batch.execute (no nesting).\n\n" +
      "Common patterns:\n" +
      "- Multi-frame animation: batch bone.setTransform across frames 1,5,10,15,...\n" +
      "- Bulk reads: batch document.getInfo + document.getLayers + layer.getProperties for several layers\n" +
      "- Keyframe + easing: batch animation.setKeyframe then animation.setInterpolation for each\n" +
      "- Multi-bone pose: batch bone.setTransform for each bone in a skeleton at the same frame\n" +
      "- Layer setup: batch layer.setName + layer.setVisibility + layer.setOpacity\n\n" +
      "Returns { results: [{ success, index, result|error }], summary: { total, executed, succeeded, failed, stoppedEarly } }. " +
      "Use stopOnError: true when later operations depend on earlier ones succeeding.",
    {
      operations: z
        .array(
          z.object({
            method: z.string().describe("The JSON-RPC method name (e.g. \"bone.setTransform\", \"layer.getProperties\")"),
            params: z.record(z.unknown()).optional().describe("Parameters for the method"),
          }),
        )
        .min(1)
        .max(config.moho.maxBatchSize)
        .describe("Array of operations to execute sequentially"),
      stopOnError: z
        .boolean()
        .optional()
        .default(false)
        .describe("If true, stop executing after the first failed operation"),
    },
    async ({ operations, stopOnError }) => {
      try {
        await ensureConnected(client);
        const timeout =
          config.moho.requestTimeout +
          operations.length * config.moho.batchTimeoutPerOp;
        const result = await client.sendRequest(
          "batch.execute",
          { operations, stopOnError },
          { timeout },
        );
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Phase 4: Creation Tools
  // =========================================================================

  // 27. layer.createLayer — Create a new layer in the document
  server.tool(
    "layer_createLayer",
    'Create a new layer in the MOHO document. Type is one of "vector", "group", "bone", "image", "switch", "particle", "note", "patch", "audio". If parentId is supplied, the bridge first selects that group so MOHO places the new layer inside it (selection-driven placement, per the official API). Returns the new layer\'s absolute id so subsequent calls can target it.',
    {
      type: z
        .enum([
          "vector",
          "group",
          "bone",
          "image",
          "switch",
          "particle",
          "note",
          "patch",
          "audio",
        ])
        .describe("Layer type to create"),
      name: z.string().optional().describe("Optional name for the new layer"),
      parentId: z
        .number()
        .optional()
        .describe(
          "Optional absolute ID of a group layer to add the new layer into. If omitted, the layer is added at the document root.",
        ),
    },
    async ({ type, name, parentId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.createLayer", {
          type,
          name,
          parentId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 28. layer.deleteLayer — Delete a layer
  server.tool(
    "layer_deleteLayer",
    "Delete a layer from the MOHO document by absolute ID. The action is undoable inside MOHO.",
    {
      layerId: z.number().describe("Absolute ID of the layer to delete"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.deleteLayer", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 29. bone.addBone — Add a new bone to a bone layer's skeleton
  server.tool(
    "bone_addBone",
    "Add a new bone to a bone layer's skeleton. All rest-pose properties (posX, posY, angle, length, scale, parentBoneId, name) are optional and applied to the bone after creation. Returns the new boneId.",
    {
      layerId: z.number().describe("Absolute ID of the bone layer"),
      name: z.string().optional().describe("Optional bone name"),
      posX: z.number().optional().describe("Rest-pose X position"),
      posY: z.number().optional().describe("Rest-pose Y position"),
      angle: z.number().optional().describe("Rest-pose angle in radians"),
      length: z.number().optional().describe("Rest-pose bone length"),
      scale: z.number().optional().describe("Rest-pose scale"),
      parentBoneId: z
        .number()
        .optional()
        .describe("Index of parent bone (-1 for no parent)"),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("bone.addBone", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 30. bone.deleteBone — Delete a bone
  server.tool(
    "bone_deleteBone",
    "Delete a bone from a bone layer's skeleton by index. Set recursive=true to also delete child bones; otherwise children are re-parented.",
    {
      layerId: z.number().describe("Absolute ID of the bone layer"),
      boneId: z.number().describe("Bone index within the skeleton"),
      recursive: z
        .boolean()
        .optional()
        .describe("If true, also delete all descendant bones (default false)"),
    },
    async ({ layerId, boneId, recursive }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("bone.deleteBone", {
          layerId,
          boneId,
          recursive,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 31. bone.setRestPose — Set the rest-pose properties of a bone
  server.tool(
    "bone_setRestPose",
    "Set the rest-pose (bind pose) properties of a bone — position, angle, length, scale, parent, name. Unlike bone_setTransform which animates at a frame, this changes the bone's setup pose directly. Useful right after bone_addBone.",
    {
      layerId: z.number().describe("Absolute ID of the bone layer"),
      boneId: z.number().describe("Bone index within the skeleton"),
      name: z.string().optional().describe("New bone name"),
      posX: z.number().optional().describe("Rest X position"),
      posY: z.number().optional().describe("Rest Y position"),
      angle: z.number().optional().describe("Rest angle in radians"),
      length: z.number().optional().describe("Bone length"),
      scale: z.number().optional().describe("Bone scale"),
      parentBoneId: z
        .number()
        .optional()
        .describe("Parent bone index, or -1 for no parent"),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("bone.setRestPose", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 32. mesh.addPoint — Add a new point to a vector layer's mesh
  server.tool(
    "mesh_addPoint",
    "Add a new mesh point (vertex) at (x, y) to a vector layer. Behavior:\n" +
      "- If connectToPointId is given: attach to that existing point (creates a curve segment).\n" +
      "- Else if mesh is empty or startNewCurve=true: create a lone point (start of a new curve).\n" +
      "- Else: append to the curve started by the most recent lone/append point.\n" +
      "Typical pattern for a quad: 1st call with no options (becomes lone), 2nd/3rd/4th calls append, then mesh_createShape with all four indices.",
    {
      layerId: z.number().describe("Absolute ID of the vector layer"),
      x: z.number().describe("X coordinate of the new point"),
      y: z.number().describe("Y coordinate of the new point"),
      frame: z
        .number()
        .optional()
        .describe("Frame to add the point at (default 0 = setup pose)"),
      connectToPointId: z
        .number()
        .optional()
        .describe("If supplied, attach the new point to this existing point index"),
      startNewCurve: z
        .boolean()
        .optional()
        .describe("Force the new point to start a new disconnected curve"),
    },
    async ({ layerId, x, y, frame, connectToPointId, startNewCurve }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("mesh.addPoint", {
          layerId,
          x,
          y,
          frame,
          connectToPointId,
          startNewCurve,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 33. mesh.createShape — Create a new shape from a list of point indices
  server.tool(
    "mesh_createShape",
    'Create a new shape on a vector layer from a list of point indices. Selects the points then calls moho:CreateShape (the documented MOHO API). Closure is determined by the points\' geometry — use a closed loop of indices for a closed shape. Set filled=false for stroke-only. Colors are hex like "#FF8800".',
    {
      layerId: z.number().describe("Absolute ID of the vector layer"),
      pointIndices: z
        .array(z.number())
        .min(2)
        .describe("Indices of mesh points to use as the shape's outline"),
      filled: z
        .boolean()
        .optional()
        .describe("Whether the shape is filled (default true)"),
      frame: z
        .number()
        .optional()
        .describe("Frame to create the shape at (default 0)"),
      name: z.string().optional().describe("Optional shape name"),
      fillColor: z
        .string()
        .optional()
        .describe("Fill color as #RRGGBB or #RRGGBBAA hex string"),
      strokeColor: z
        .string()
        .optional()
        .describe("Stroke color as #RRGGBB or #RRGGBBAA hex string"),
      strokeWidth: z
        .number()
        .optional()
        .describe("Stroke line width in pixels"),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("mesh.createShape", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 34. document.save — Save the current document
  server.tool(
    "document_save",
    "Save the current MOHO document. Pass filePath to Save As; omit it to save to the document's existing path.",
    {
      filePath: z
        .string()
        .optional()
        .describe(
          "Optional absolute path to save to (Save As). If omitted, saves to the current document path.",
        ),
    },
    async ({ filePath }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("document.save", { filePath });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Phase 5: Curves, binding, smart bones, reparenting
  // =========================================================================

  // 35. mesh.setPointCurvature — Smooth/sharpen a single mesh point
  server.tool(
    "mesh_setPointCurvature",
    "Set the curvature passing through a single mesh point. The simplest way to make a vertex smooth (positive curvature, ~1.0) vs sharp/corner (0). Affects all curves through that point. Use this for soft, hand-drawn-looking shapes — without it, mesh_createShape produces flat polygons.",
    {
      layerId: z.number().describe("Absolute ID of the vector layer"),
      pointIndex: z.number().describe("Mesh-global point index"),
      curvature: z
        .number()
        .describe(
          "Curvature value. 0 = sharp corner, ~1.0 = smooth, negative for inverted curves",
        ),
      frame: z.number().optional().describe("Frame to set the curvature at (default 0)"),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("mesh.setPointCurvature", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 36. mesh.getCurves — List curves with mesh-point indices for each
  server.tool(
    "mesh_getCurves",
    "List all curves in a vector layer's mesh. Each curve entry includes its closed flag and an array of points pairing the curve-local index (curvePointIndex) with the mesh-global index (meshPointIndex). Call this before mesh_setBezierHandle, which needs curve-local indices.",
    {
      layerId: z.number().describe("Absolute ID of the vector layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("mesh.getCurves", { layerId });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 37. mesh.setBezierHandle — Direct control of a bezier handle
  server.tool(
    "mesh_setBezierHandle",
    "Set one of the two bezier control handles on a curve point. ptID is curve-local — find it via mesh_getCurves. prePoint=false (default) targets the outgoing handle; true targets the incoming handle. syncAngles=true (default) keeps the opposite handle tangent.",
    {
      layerId: z.number().describe("Absolute ID of the vector layer"),
      curveIndex: z.number().describe("Index of the curve in the mesh"),
      curvePointIndex: z
        .number()
        .describe("Curve-local index of the point (NOT the mesh-global index)"),
      x: z.number().describe("Handle X position"),
      y: z.number().describe("Handle Y position"),
      frame: z.number().optional().describe("Frame to set the handle at (default 0)"),
      prePoint: z
        .boolean()
        .optional()
        .describe("false = outgoing handle (default), true = incoming"),
      syncAngles: z
        .boolean()
        .optional()
        .describe("Keep the opposite handle tangent (default true)"),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("mesh.setBezierHandle", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 38. mesh.bindPoints — Bind mesh points to a bone
  server.tool(
    "mesh_bindPoints",
    "Bind one or more mesh points to a bone so the bone deforms them when it moves. boneId values: -1 = unbind, -2 = flexi-bind to all bones in the parent bone layer, otherwise the index of a specific bone in the parent skeleton.",
    {
      layerId: z.number().describe("Absolute ID of the vector layer"),
      pointIndices: z
        .array(z.number())
        .min(1)
        .describe("Mesh-global indices of the points to bind"),
      boneId: z
        .number()
        .describe(
          "Bone to bind to. -1 = unbind, -2 = flexi-bind to all bones, else specific bone index",
        ),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("mesh.bindPoints", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 39. layer.setParentBone — Set the controlling parent bone for a layer
  server.tool(
    "layer_setParentBone",
    "Set the controlling parent bone for a layer (e.g. parent a body part to a hip bone). Pass boneId=-1 to clear.",
    {
      layerId: z.number().describe("Absolute ID of the layer"),
      boneId: z
        .number()
        .describe("Bone index in the parent skeleton, or -1 to clear"),
    },
    async ({ layerId, boneId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setParentBone", {
          layerId,
          boneId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 40. layer.placeInGroup — Reparent a layer into a group
  server.tool(
    "layer_placeInGroup",
    "Move a layer into the given group layer. Set top=true to place it at the top of the group's stack, false (default) for the bottom.",
    {
      layerId: z.number().describe("Layer to move"),
      parentGroupId: z.number().describe("Absolute ID of the destination group layer"),
      top: z
        .boolean()
        .optional()
        .describe("Place at top of the group stack (default false = bottom)"),
    },
    async ({ layerId, parentGroupId, top }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.placeInGroup", {
          layerId,
          parentGroupId,
          top,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 41. layer.placeBehind — Reorder a layer behind another
  server.tool(
    "layer_placeBehind",
    "Move a layer behind (below) another layer in the layer ordering. Both layers must be in the same group.",
    {
      layerId: z.number().describe("Layer to move"),
      behindLayerId: z.number().describe("Layer to position behind"),
    },
    async ({ layerId, behindLayerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.placeBehind", {
          layerId,
          behindLayerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 42. layer.activateAction — Switch into action-edit mode (or back to mainline)
  server.tool(
    "layer_activateAction",
    'Activate an action on a layer for editing. While an action is active, any keyframes set via animation_setKeyframe / bone_setTransform are stored in that action — this is the mechanism for recording smart-bone dials. Pass actionName="" (or omit) to return to the mainline timeline.',
    {
      layerId: z.number().describe("Absolute ID of the layer"),
      actionName: z
        .string()
        .optional()
        .describe('Action name. Empty string (default) = mainline timeline'),
    },
    async ({ layerId, actionName }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.activateAction", {
          layerId,
          actionName,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 43. layer.listActions — List all actions on a layer
  server.tool(
    "layer_listActions",
    "List all actions on a layer, including which (if any) is currently being edited and which are smart-bone actions.",
    {
      layerId: z.number().describe("Absolute ID of the layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.listActions", { layerId });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 44. bone.createSmartAction — Create a smart-bone action for a bone
  server.tool(
    "bone_createSmartAction",
    "Create a smart-bone action on the given bone layer, named the same as the target bone. After creating it, call layer_activateAction with the same name and any subsequent bone keyframes get recorded into the dial — when the bone is later rotated, the dial replays proportionally.",
    {
      layerId: z.number().describe("Absolute ID of the bone layer"),
      boneId: z.number().describe("Bone index in the skeleton"),
      frame: z
        .number()
        .optional()
        .describe("Frame to insert the action at (default 0)"),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("bone.createSmartAction", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Phase 6: Camera, layer effects, particles, undo/redo
  // =========================================================================

  // 45. document.setCamera — Animate the camera at a frame
  server.tool(
    "document_setCamera",
    "Set the document camera at a frame. The MOHO camera lives on the document with channels fCameraTrack (3D position), fCameraPanTilt (tilt+pan radians), fCameraRoll (Z rotation radians), fCameraZoom (BaseFoV/FoV; 1.0 = default). All component params are optional — only supplied axes are written, others preserve their current keyframe value.",
    {
      frame: z.number().describe("Frame number to keyframe at"),
      posX: z.number().optional().describe("Camera X position"),
      posY: z.number().optional().describe("Camera Y position"),
      posZ: z.number().optional().describe("Camera Z position (zoom dolly)"),
      tilt: z.number().optional().describe("Camera tilt around X axis (radians)"),
      pan: z.number().optional().describe("Camera pan around Y axis (radians)"),
      roll: z.number().optional().describe("Camera roll around Z axis (radians)"),
      zoom: z
        .number()
        .optional()
        .describe("Camera zoom; 1.0 = default field of view, >1 = zoomed in"),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("document.setCamera", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 46. document.undo — Undo last change
  server.tool(
    "document_undo",
    "Undo the most recent document change. Returns success=false with a message if there is nothing to undo.",
    {},
    async () => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("document.undo");
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 47. document.redo — Redo last undone change
  server.tool(
    "document_redo",
    "Redo the most recently undone change. Returns success=false with a message if there is nothing to redo.",
    {},
    async () => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("document.redo");
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 48. layer.setBlur — Animate a layer's blur amount
  server.tool(
    "layer_setBlur",
    "Set a layer's blur amount at a frame (fBlur is an AnimVal channel on MohoLayer). Useful for depth-of-field, atmospheric perspective, or blur-then-sharpen reveals.",
    {
      layerId: z.number().describe("Absolute ID of the layer"),
      frame: z.number().describe("Frame to keyframe at"),
      amount: z.number().describe("Blur amount in pixels"),
    },
    async ({ layerId, frame, amount }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setBlur", {
          layerId,
          frame,
          amount,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 49. layer.setShadow — Animate a layer's drop shadow
  server.tool(
    "layer_setShadow",
    'Set a layer\'s drop-shadow effect at a frame. All components are optional — only supplied ones are written. Pass enabled=true to turn the shadow on, false to turn it off. color is "#RRGGBB" or "#RRGGBBAA".',
    {
      layerId: z.number().describe("Absolute ID of the layer"),
      frame: z.number().describe("Frame to keyframe at"),
      enabled: z.boolean().optional().describe("Toggle the shadow on/off"),
      offset: z.number().optional().describe("Shadow offset distance in pixels"),
      blur: z.number().optional().describe("Shadow blur radius in pixels"),
      angle: z.number().optional().describe("Shadow direction in radians"),
      color: z.string().optional().describe("Shadow color (#RRGGBB or #RRGGBBAA)"),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setShadow", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 50. layer.setOutline — Animate a layer's outline
  server.tool(
    "layer_setOutline",
    'Set a layer\'s outline at a frame. Pass enabled to toggle the outline; width / color animate. color is "#RRGGBB" or "#RRGGBBAA".',
    {
      layerId: z.number().describe("Absolute ID of the layer"),
      frame: z.number().describe("Frame to keyframe at"),
      enabled: z.boolean().optional().describe("Toggle outline on/off"),
      width: z.number().optional().describe("Outline width in pixels"),
      color: z.string().optional().describe("Outline color hex"),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setOutline", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 51. particle.setEmitter — Configure a particle layer's emitter
  server.tool(
    "particle_setEmitter",
    "Configure the emitter on a particle layer (rain, snow, sparks, smoke, etc.). All settings are optional — only supplied ones are applied. The handler calls FinalizeSettings() automatically when done.\n\nVelocity / direction are scalars + spreads. Source dimensions describe the emission region. randomSeed lets you re-roll the simulation deterministically.",
    {
      layerId: z.number().describe("Absolute ID of the particle layer"),
      numParticles: z.number().optional().describe("Total particles to simulate"),
      displayNumParticles: z
        .number()
        .optional()
        .describe("Particles to display (defaults to numParticles if omitted)"),
      lifetime: z.number().optional().describe("Particle lifetime in frames"),
      velocity: z.number().optional().describe("Emission velocity"),
      velocitySpread: z.number().optional().describe("Velocity randomization spread"),
      directionAngle: z.number().optional().describe("Emission direction in radians"),
      directionSpread: z
        .number()
        .optional()
        .describe("Direction randomization spread in radians"),
      accelerationAngle: z
        .number()
        .optional()
        .describe("Acceleration direction (radians) — e.g. -π/2 for gravity"),
      accelerationRate: z.number().optional().describe("Acceleration magnitude"),
      damping: z.number().optional().describe("Velocity damping factor"),
      evenlySpaced: z
        .boolean()
        .optional()
        .describe("Emit at fixed intervals instead of randomly"),
      orientation: z
        .boolean()
        .optional()
        .describe("Orient particles along their motion path"),
      freeFloating: z.boolean().optional().describe("Free-floating particles"),
      fullSpeedStart: z
        .boolean()
        .optional()
        .describe("Start emitting at full rate from frame 0"),
      randomStartTime: z
        .boolean()
        .optional()
        .describe("Stagger emission start times"),
      sourceWidth: z.number().optional().describe("Emitter region width"),
      sourceHeight: z.number().optional().describe("Emitter region height"),
      sourceDepth: z.number().optional().describe("Emitter region depth"),
      randomSeed: z
        .number()
        .optional()
        .describe("Random seed; change to re-roll the simulation"),
    },
    async (params) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("particle.setEmitter", params);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );
}
