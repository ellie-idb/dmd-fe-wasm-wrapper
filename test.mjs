import fs from 'fs';
import { WASI } from 'wasi';

const wasi = new WASI({
        args: process.argv,
        env: process.env
});

const importObject = { wasi_snapshot_preview1: wasi.wasiImport, wasi_unstable: wasi.wasiImport };

const wasm = await WebAssembly.compile(fs.readFileSync('./fe-wrapper.wasm'));
const instance = await WebAssembly.instantiate(wasm, importObject);

wasi.start(instance);
