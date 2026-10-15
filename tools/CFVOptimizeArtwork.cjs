// Offline authoring tool; sharp is not an app or Xcode build dependency.
// Usage: CFV_SHARP_MODULE=/path/to/sharp node tools/CFVOptimizeArtwork.cjs ORIGINALS OUTPUT
// Always use original generated PNGs, never a previously optimized directory.
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.CFV_SHARP_MODULE || 'sharp');

async function main() {
    const [inputArgument, outputArgument] = process.argv.slice(2);
    if (!inputArgument || !outputArgument) {
        throw new Error('Expected separate ORIGINALS and OUTPUT directories.');
    }

    const input = await fs.realpath(inputArgument);
    await fs.mkdir(outputArgument, { recursive: true });
    const output = await fs.realpath(outputArgument);
    if (input === output) {
        throw new Error('Keep originals separate to avoid repeated lossy compression.');
    }

    const species = ['paper-butterfly', 'folded-bird', 'paper-fish', 'paper-rabbit', 'paper-fox', 'paper-deer'];
    const report = {
        method: '1152px maximum edge, sRGB, 256-color PNG with alpha, dithering 0.8',
        sharp: sharp.versions.sharp,
        imagequant: sharp.versions.imagequant,
        assets: []
    };

    for (const id of species) {
        for (let stage = 0; stage <= 2; stage++) {
            const name = `CFV-${id}-${stage}.png`;
            const original = await fs.readFile(path.join(input, name));
            const metadata = await sharp(original).metadata();
            if (!metadata.hasAlpha) {
                throw new Error(`Expected transparent source: ${name}`);
            }

            // The largest portrait illustration is 380pt at 3x (1140px).
            // PNG remains compatible with the existing ImageIO loader on iOS 15.
            const optimized = await sharp(original)
                .resize({ width: 1152, height: 1152, fit: 'inside', withoutEnlargement: true })
                .toColourspace('srgb')
                .png({ palette: true, colours: 256, quality: 100, dither: 0.8, compressionLevel: 9, effort: 10 })
                .toBuffer();
            const result = await sharp(optimized).metadata();
            if (!result.hasAlpha || optimized.length >= original.length) {
                throw new Error(`Optimization did not preserve alpha or reduce size: ${name}`);
            }

            await fs.writeFile(path.join(output, name), optimized);
            report.assets.push({
                file: name,
                originalBytes: original.length,
                optimizedBytes: optimized.length,
                width: result.width,
                height: result.height,
                originalSHA256: crypto.createHash('sha256').update(original).digest('hex'),
                optimizedSHA256: crypto.createHash('sha256').update(optimized).digest('hex')
            });
        }
    }

    report.originalBytes = report.assets.reduce((sum, asset) => sum + asset.originalBytes, 0);
    report.optimizedBytes = report.assets.reduce((sum, asset) => sum + asset.optimizedBytes, 0);
    console.log(JSON.stringify(report, null, 2));
}

main().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
});
