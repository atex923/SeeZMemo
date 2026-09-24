import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const sharp = require(process.env.SEEZMEMO_NODE_MODULES
  ? path.join(process.env.SEEZMEMO_NODE_MODULES, "sharp")
  : "sharp");

const root = path.resolve(import.meta.dirname, "..");
const renderRoot = path.join(root, "renders");
const devices = {
  iPhone16: { width: 1179, height: 2556 },
  iPhone17Pro: { width: 1206, height: 2622 },
};
const screens = ["01_home", "02_camera", "03_editor_photos", "04_editor_details", "05_add_photo", "06_ocr", "07_map", "08_nearby_map", "09_visit_date", "10_draft_saved", "11_records_list", "12_records_map", "13_journal_share"];

for (const [device, dimensions] of Object.entries(devices)) {
  const deviceDir = path.join(renderRoot, device);
  await fs.mkdir(deviceDir, { recursive: true });
  const thumbs = [];
  for (const screen of screens) {
    const source = path.join(renderRoot, "svg", `${device}_${screen}.svg`);
    const output = path.join(deviceDir, `${screen}.png`);
    await sharp(source, { density: 216 }).resize(dimensions.width, dimensions.height, { fit: "fill" }).png().toFile(output);
    const thumb = await sharp(output).resize({ width: 294, height: 655, fit: "contain", background: "#dfe5e2" }).png().toBuffer();
    thumbs.push({ input: thumb, left: 24 + (thumbs.length % 4) * 318, top: 40 + Math.floor(thumbs.length / 4) * 695 });
  }
  await sharp({ create: { width: 1296, height: 2820, channels: 4, background: "#dfe5e2" } })
    .composite(thumbs)
    .png()
    .toFile(path.join(renderRoot, `${device}_overview.png`));
}
