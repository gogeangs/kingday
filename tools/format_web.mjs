// index.html 의 <style>·<script> 안만 prettier 로 정리 (HTML 본문은 그대로). 코드 정리 4단계.
//   npm i --no-save prettier@3.3.3 && node tools/format_web.mjs index.html index.html
// 정리 뒤에는 tools/refactor_check.py 로 화면 모양이 그대로인지 확인.
import * as prettier from 'prettier';
import fs from 'fs';
const [,, src, dst] = process.argv;
let html = fs.readFileSync(src, 'utf8');
const opt = { printWidth: 140, singleQuote: true, arrowParens: 'avoid', trailingComma: 'none' };
const parts = [];
html = await replaceAsync(html, /<style>([\s\S]*?)<\/style>/g, async (m, css) => '<style>\n' + (await prettier.format(css, { ...opt, parser: 'css' })) + '</style>');
html = await replaceAsync(html, /<script>([\s\S]*?)<\/script>/g, async (m, js) => '<script>\n' + (await prettier.format(js, { ...opt, parser: 'babel' })) + '</script>');
fs.writeFileSync(dst, html);
async function replaceAsync(str, re, fn) { const ps = []; str.replace(re, (...a) => { ps.push(fn(...a)); return ''; }); const r = await Promise.all(ps); let i = 0; return str.replace(re, () => r[i++]); }
