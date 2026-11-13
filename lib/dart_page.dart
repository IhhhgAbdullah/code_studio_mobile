import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _dartHtml = r'''
<!DOCTYPE html>
<html dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  * { box-sizing: border-box; }
  body { font-family: sans-serif; margin: 0; padding: 12px; background: #0D2B52; color: #fff; }
  .card { background: #132F5A; border: 1px solid #D4AF37; border-radius: 14px; padding: 12px; margin-bottom: 12px; }
  .card-title { color: #D4AF37; font-weight: bold; margin-bottom: 8px; font-size: 14px; }
  textarea { width: 100%; min-height: 240px; background: #0A1F3D; color: #e6edf7; border: none;
    border-radius: 10px; padding: 10px; font-family: monospace; font-size: 14px; direction: ltr; }
  .row { display: flex; gap: 8px; margin-top: 8px; }
  .row > * { flex: 1; }
  button { width: 100%; padding: 13px; font-size: 16px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; }
  button.alt { background: #2A4A7A; color: #fff; }
  pre { background: #0A1F3D; color: #7CFC7C; padding: 10px; border-radius: 10px; min-height: 90px;
    margin: 0; direction: ltr; white-space: pre-wrap; text-align: left; font-family: monospace; font-size: 14px; }
  .err { color: #ff6b6b; font-weight: bold; }
  .note { color: #cfd8e6; font-size: 12px; margin-top: 6px; }
</style>
</head>
<body>
<div class="card">
  <div class="card-title">كود Dart (مفسّر تجريبي: متغيرات، دوال، شروط، حلقات، قوائم، print)</div>
  <textarea id="code" spellcheck="false"></textarea>
  <div class="row">
    <button id="run">تشغيل</button>
    <button id="reset" class="alt">استعادة المثال</button>
  </div>
</div>
<div class="card">
  <div class="card-title">المخرجات</div>
  <pre id="out">المخرجات ستظهر هنا</pre>
  <div class="note">مفسّر تجريبي يعمل داخل التطبيق دون إنترنت. لا يدعم الكلاسات ولا Flutter بعد.</div>
</div>
<script>
  const SAMPLE = `void main() {
  var name = "Abdullah";
  int total = 0;
  for (int i = 1; i <= 5; i++) {
    total += i;
  }
  print("مرحباً $name");
  print("المجموع: $total");
  print(factorial(5));
}

int factorial(int n) {
  if (n <= 1) {
    return 1;
  }
  return n * factorial(n - 1);
}`;

  class DErr extends Error {}
  class Ret { constructor(v) { this.v = v; } }
  const BRK = { brk: true }, CNT = { cnt: true };
  const LIMIT = 300000;
  const TYPES = ['var','final','const','int','double','num','String','bool','dynamic','void'];
  const KW = new Set(TYPES.concat(['if','else','while','for','return','break','continue','true','false','null','in','class']));
  const OPS2 = ['==','!=','<=','>=','&&','||','+=','-=','*=','/=','%=','++','--','~/'];
  const PREC = [['||'], ['&&'], ['==','!='], ['<','>','<=','>='], ['+','-'], ['*','/','%','~/']];
  let out = [], steps = 0;

  function fail(msg, line) { const e = new DErr(msg); e.line = line; throw e; }

  function tokenize(src) {
    const toks = []; let i = 0, line = 1; const n = src.length;
    const push = (t, v) => toks.push({ t, v, line });
    while (i < n) {
      const c = src[i];
      if (c === '\n') { line++; i++; continue; }
      if (/\s/.test(c)) { i++; continue; }
      if (c === '/' && src[i + 1] === '/') { while (i < n && src[i] !== '\n') i++; continue; }
      if (c === '/' && src[i + 1] === '*') {
        i += 2;
        while (i < n && !(src[i] === '*' && src[i + 1] === '/')) { if (src[i] === '\n') line++; i++; }
        i += 2; continue;
      }
      if (/[0-9]/.test(c)) {
        let j = i;
        while (j < n && (/[0-9]/.test(src[j]) || (src[j] === '.' && /[0-9]/.test(src[j + 1] || '')))) j++;
        push('num', parseFloat(src.slice(i, j))); i = j; continue;
      }
      if (c === '"' || c === "'") {
        i++;
        const parts = []; let buf = '';
        while (i < n && src[i] !== c) {
          const d = src[i];
          if (d === '\\') {
            const e = src[i + 1]; const map = { n: '\n', t: '\t' };
            buf += (map[e] !== undefined ? map[e] : e); i += 2;
          } else if (d === '$' && src[i + 1] === '{') {
            let j = i + 2, depth = 1;
            while (j < n) {
              if (src[j] === '{') depth++;
              else if (src[j] === '}') { depth--; if (depth === 0) break; }
              j++;
            }
            if (buf) { parts.push(buf); buf = ''; }
            parts.push({ e: src.slice(i + 2, j) }); i = j + 1;
          } else if (d === '$' && /[A-Za-z_]/.test(src[i + 1] || '')) {
            let j = i + 1;
            while (j < n && /\w/.test(src[j])) j++;
            if (buf) { parts.push(buf); buf = ''; }
            parts.push({ e: src.slice(i + 1, j) }); i = j;
          } else {
            if (d === '\n') line++;
            buf += d; i++;
          }
        }
        if (i >= n) fail('نص غير مغلق', line);
        if (buf) parts.push(buf);
        i++; push('str', parts); continue;
      }
      if (/[A-Za-z_]/.test(c)) {
        let j = i;
        while (j < n && /\w/.test(src[j])) j++;
        const w = src.slice(i, j);
        push(KW.has(w) ? 'kw' : 'id', w); i = j; continue;
      }
      const two = src.substr(i, 2);
      if (OPS2.includes(two)) { push('op', two); i += 2; continue; }
      if ('+-*/%<>=!?:;,.(){}[]'.includes(c)) { push('op', c); i++; continue; }
      fail('رمز غير معروف: ' + c, line);
    }
    return toks;
  }

  class Parser {
    constructor(t) { this.t = t; this.p = 0; this.last = t.length ? t[t.length - 1].line : 1; }
    peek(o = 0) { return this.t[this.p + o] || { t: 'eof', v: 'نهاية الكود', line: this.last }; }
    is(v, o = 0) { const k = this.peek(o); return k.v === v && k.t !== 'str'; }
    eat(v) { if (this.is(v)) { this.p++; return true; } return false; }
    expect(v) {
      if (!this.eat(v)) fail('متوقع "' + v + '" وجدت "' + this.peek().v + '"', this.peek().line);
    }
    program() {
      const out = [];
      while (this.p < this.t.length) out.push(this.stmt());
      return out;
    }
    isDecl() {
      const k = this.peek();
      return k.t === 'kw' && TYPES.includes(k.v) && this.peek(1).t === 'id';
    }
    isFunc() {
      let q = this.p; const k = this.t[q];
      if (k && k.t === 'kw' && TYPES.includes(k.v) && this.t[q + 1] && this.t[q + 1].t === 'id') q++;
      if (!this.t[q] || this.t[q].t !== 'id' || !this.t[q + 1] || this.t[q + 1].v !== '(') return false;
      let d = 0, r = q + 1;
      for (; r < this.t.length; r++) {
        const tk = this.t[r];
        if (tk.t === 'op') {
          if (tk.v === '(') d++;
          else if (tk.v === ')') { d--; if (d === 0) break; }
        }
      }
      return !!this.t[r + 1] && this.t[r + 1].v === '{';
    }
    stmt() {
      const line = this.peek().line;
      if (this.is('{')) return this.block();
      if (this.eat('if')) {
        this.expect('('); const c = this.expr(); this.expect(')');
        const th = this.stmt();
        const el = this.eat('else') ? this.stmt() : null;
        return { k: 'if', c, th, el, line };
      }
      if (this.eat('while')) {
        this.expect('('); const c = this.expr(); this.expect(')');
        return { k: 'while', c, body: this.stmt(), line };
      }
      if (this.eat('for')) return this.forStmt(line);
      if (this.eat('return')) {
        const e = (this.is(';') || this.is('}')) ? null : this.expr();
        this.eat(';'); return { k: 'return', e, line };
      }
      if (this.eat('break')) { this.eat(';'); return { k: 'break', line }; }
      if (this.eat('continue')) { this.eat(';'); return { k: 'continue', line }; }
      if (this.is('class')) fail('الكلاسات غير مدعومة في هذه المرحلة', line);
      if (this.isFunc()) return this.funcDecl();
      if (this.isDecl()) { const d = this.decl(); this.eat(';'); return d; }
      const e = this.expr(); this.eat(';');
      return { k: 'expr', e, line };
    }
    forStmt(line) {
      this.expect('(');
      let q = this.p;
      if (this.t[q] && this.t[q].t === 'kw' && TYPES.includes(this.t[q].v)) q++;
      if (this.t[q] && this.t[q].t === 'id' && this.t[q + 1] && this.t[q + 1].v === 'in') {
        this.p = q; const name = this.peek().v; this.p += 2;
        const it = this.expr(); this.expect(')');
        return { k: 'forin', name, it, body: this.stmt(), line };
      }
      let init = null;
      if (!this.is(';')) init = this.isDecl() ? this.decl() : { k: 'expr', e: this.expr(), line };
      this.expect(';');
      const cond = this.is(';') ? null : this.expr();
      this.expect(';');
      const upd = this.is(')') ? null : this.expr();
      this.expect(')');
      return { k: 'for', init, cond, upd, body: this.stmt(), line };
    }
    funcDecl() {
      const line = this.peek().line;
      if (this.peek().t === 'kw') this.p++;
      const name = this.peek().v; this.p++;
      this.expect('(');
      const params = [];
      while (!this.is(')')) {
        if (this.peek().t === 'eof') fail('ناقص ")"', line);
        if (this.peek().t === 'kw' && TYPES.includes(this.peek().v)) this.p++;
        params.push(this.peek().v); this.p++;
        if (!this.eat(',')) break;
      }
      this.expect(')');
      return { k: 'fn', name, params, body: this.block(), line };
    }
    block() {
      const line = this.peek().line;
      this.expect('{');
      const body = [];
      while (!this.is('}')) {
        if (this.peek().t === 'eof') fail('ناقص "}"', line);
        body.push(this.stmt());
      }
      this.expect('}');
      return { k: 'block', body, line };
    }
    decl() {
      const line = this.peek().line; this.p++;
      const list = [];
      do {
        const name = this.peek().v; this.p++;
        const init = this.eat('=') ? this.expr() : null;
        list.push({ name, init });
      } while (this.eat(','));
      return { k: 'decl', list, line };
    }
    expr() { return this.assign(); }
    assign() {
      const l = this.cond();
      const k = this.peek();
      if (k.t === 'op' && ['=', '+=', '-=', '*=', '/=', '%='].includes(k.v)) {
        this.p++;
        return { k: 'assign', op: k.v, target: l, v: this.assign(), line: k.line };
      }
      return l;
    }
    cond() {
      const c = this.bin(0);
      if (this.eat('?')) {
        const a = this.assign(); this.expect(':'); const b = this.assign();
        return { k: 'cond', c, a, b };
      }
      return c;
    }
    bin(lv) {
      if (lv >= PREC.length) return this.unary();
      let l = this.bin(lv + 1);
      while (this.peek().t === 'op' && PREC[lv].includes(this.peek().v)) {
        const k = this.peek(); this.p++;
        const r = this.bin(lv + 1);
        l = { k: 'bin', op: k.v, l, r, line: k.line };
      }
      return l;
    }
    unary() {
      const k = this.peek();
      if (k.t === 'op' && (k.v === '!' || k.v === '-')) {
        this.p++;
        return { k: 'un', op: k.v, e: this.unary(), line: k.line };
      }
      return this.postfix();
    }
    postfix() {
      let e = this.primary();
      for (;;) {
        if (this.eat('(')) {
          const args = [];
          while (!this.is(')')) { args.push(this.expr()); if (!this.eat(',')) break; }
          this.expect(')');
          e = { k: 'call', f: e, args, line: this.peek().line };
        } else if (this.eat('[')) {
          const i = this.expr(); this.expect(']');
          e = { k: 'index', o: e, i };
        } else if (this.eat('.')) {
          const n = this.peek().v; this.p++;
          e = { k: 'member', o: e, name: n };
        } else if (this.is('++') || this.is('--')) {
          const op = this.peek().v; this.p++;
          e = { k: 'post', op, target: e };
        } else return e;
      }
    }
    primary() {
      const k = this.peek(); this.p++;
      if (k.t === 'num') return { k: 'lit', v: k.v };
      if (k.t === 'str') return { k: 'str', parts: k.v };
      if (k.t === 'kw' && k.v === 'true') return { k: 'lit', v: true };
      if (k.t === 'kw' && k.v === 'false') return { k: 'lit', v: false };
      if (k.t === 'kw' && k.v === 'null') return { k: 'lit', v: null };
      if (k.t === 'id') return { k: 'id', name: k.v, line: k.line };
      if (k.t === 'op' && k.v === '(') { const e = this.expr(); this.expect(')'); return e; }
      if (k.t === 'op' && k.v === '[') {
        const items = [];
        while (!this.is(']')) { items.push(this.expr()); if (!this.eat(',')) break; }
        this.expect(']');
        return { k: 'list', items };
      }
      fail('تعبير غير صحيح: "' + k.v + '"', k.line);
    }
  }

  class Env {
    constructor(parent) { this.v = new Map(); this.parent = parent; }
    has(n) { for (let e = this; e; e = e.parent) if (e.v.has(n)) return e; return null; }
    get(n) { const e = this.has(n); if (!e) throw new DErr('غير معرّف: ' + n); return e.v.get(n); }
    set(n, val) { const e = this.has(n); if (!e) throw new DErr('غير معرّف: ' + n); e.v.set(n, val); }
    define(n, val) { this.v.set(n, val); }
  }

  function stringify(v) {
    if (v === null || v === undefined) return 'null';
    if (typeof v === 'boolean') return v ? 'true' : 'false';
    if (Array.isArray(v)) return '[' + v.map(stringify).join(', ') + ']';
    if (typeof v === 'function' || (v && v.fn)) return '<fn>';
    return String(v);
  }
  function truthy(v) {
    if (typeof v !== 'boolean') throw new DErr('الشرط يجب أن يكون bool');
    return v;
  }

  function binVal(op, a, b) {
    switch (op) {
      case '+': return (typeof a === 'string' || typeof b === 'string') ? stringify(a) + stringify(b) : a + b;
      case '-': return a - b;
      case '*': return a * b;
      case '/': if (b === 0) throw new DErr('القسمة على صفر'); return a / b;
      case '~/': if (b === 0) throw new DErr('القسمة على صفر'); return Math.trunc(a / b);
      case '%': if (b === 0) throw new DErr('القسمة على صفر'); return a % b;
      case '==': return a === b;
      case '!=': return a !== b;
      case '<': return a < b;
      case '>': return a > b;
      case '<=': return a <= b;
      case '>=': return a >= b;
    }
    throw new DErr('عملية غير مدعومة: ' + op);
  }

  function member(o, name) {
    if (name === 'length' && (typeof o === 'string' || Array.isArray(o))) return o.length;
    if (Array.isArray(o)) {
      if (name === 'add') return x => { o.push(x); return null; };
      if (name === 'removeLast') return () => o.pop();
      if (name === 'contains') return x => o.includes(x);
      if (name === 'indexOf') return x => o.indexOf(x);
      if (name === 'isEmpty') return o.length === 0;
    }
    if (typeof o === 'string') {
      if (name === 'toUpperCase') return () => o.toUpperCase();
      if (name === 'toLowerCase') return () => o.toLowerCase();
      if (name === 'contains') return x => o.includes(x);
    }
    throw new DErr('الخاصية غير معروفة: ' + name);
  }

  function strOf(node, env) {
    if (!node.cache) node.cache = node.parts.map(p => typeof p === 'string' ? p : new Parser(tokenize(p.e)).expr());
    return node.cache.map(p => typeof p === 'string' ? p : stringify(evalN(p, env))).join('');
  }

  function setTarget(t, v, env) {
    if (t.k === 'id') { env.set(t.name, v); return; }
    if (t.k === 'index') { const o = evalN(t.o, env); const i = evalN(t.i, env); o[i] = v; return; }
    throw new DErr('لا يمكن الإسناد إلى هذا التعبير');
  }

  function assign(n, env) {
    let v = evalN(n.v, env);
    if (n.op !== '=') { const cur = evalN(n.target, env); v = binVal(n.op.slice(0, 1), cur, v); }
    setTarget(n.target, v, env);
    return v;
  }

  function call(n, env) {
    const args = n.args.map(a => evalN(a, env));
    let f;
    if (n.f.k === 'member') f = member(evalN(n.f.o, env), n.f.name);
    else f = evalN(n.f, env);
    if (typeof f === 'function') return f(...args);
    if (f && f.fn) return callUser(f, args);
    throw new DErr('ليس دالة قابلة للاستدعاء');
  }

  function callUser(f, args) {
    const env = new Env(f.env);
    f.params.forEach((p, i) => env.define(p, i < args.length ? args[i] : null));
    try { exec(f.body, env); }
    catch (e) { if (e instanceof Ret) return e.v; throw e; }
    return null;
  }

  function evalN(n, env) {
    switch (n.k) {
      case 'lit': return n.v;
      case 'str': return strOf(n, env);
      case 'id': return env.get(n.name);
      case 'list': return n.items.map(x => evalN(x, env));
      case 'un': { const v = evalN(n.e, env); return n.op === '!' ? !truthy(v) : -v; }
      case 'cond': return truthy(evalN(n.c, env)) ? evalN(n.a, env) : evalN(n.b, env);
      case 'bin':
        if (n.op === '&&') return truthy(evalN(n.l, env)) && truthy(evalN(n.r, env));
        if (n.op === '||') return truthy(evalN(n.l, env)) || truthy(evalN(n.r, env));
        return binVal(n.op, evalN(n.l, env), evalN(n.r, env));
      case 'assign': return assign(n, env);
      case 'post': {
        const old = evalN(n.target, env);
        setTarget(n.target, old + (n.op === '++' ? 1 : -1), env);
        return old;
      }
      case 'member': return member(evalN(n.o, env), n.name);
      case 'index': {
        const o = evalN(n.o, env), i = evalN(n.i, env);
        if (!Array.isArray(o) && typeof o !== 'string') throw new DErr('لا يمكن الفهرسة هنا');
        if (i < 0 || i >= o.length) throw new DErr('فهرس خارج النطاق: ' + i);
        return o[i];
      }
      case 'call': return call(n, env);
    }
    throw new DErr('تعبير غير مدعوم');
  }

  function exec(s, env) {
    if (++steps > LIMIT) fail('تجاوز الحد المسموح من الخطوات (احتمال حلقة لا نهائية)', s.line);
    try {
      switch (s.k) {
        case 'expr': evalN(s.e, env); return;
        case 'decl':
          for (const d of s.list) env.define(d.name, d.init ? evalN(d.init, env) : null);
          return;
        case 'block': {
          const inner = new Env(env);
          for (const x of s.body) exec(x, inner);
          return;
        }
        case 'if':
          if (truthy(evalN(s.c, env))) exec(s.th, env);
          else if (s.el) exec(s.el, env);
          return;
        case 'while':
          while (truthy(evalN(s.c, env))) {
            try { exec(s.body, env); }
            catch (e) { if (e === BRK) break; if (e === CNT) continue; throw e; }
          }
          return;
        case 'for': {
          const inner = new Env(env);
          if (s.init) exec(s.init, inner);
          while (!s.cond || truthy(evalN(s.cond, inner))) {
            try { exec(s.body, inner); }
            catch (e) { if (e === BRK) break; if (e !== CNT) throw e; }
            if (s.upd) evalN(s.upd, inner);
          }
          return;
        }
        case 'forin': {
          const it = evalN(s.it, env);
          for (const item of it) {
            const inner = new Env(env);
            inner.define(s.name, item);
            try { exec(s.body, inner); }
            catch (e) { if (e === BRK) break; if (e !== CNT) throw e; }
          }
          return;
        }
        case 'fn':
          env.define(s.name, { fn: true, name: s.name, params: s.params, body: s.body, env });
          return;
        case 'return': throw new Ret(s.e ? evalN(s.e, env) : null);
        case 'break': throw BRK;
        case 'continue': throw CNT;
      }
    } catch (e) {
      if (e instanceof DErr && !e.line) e.line = s.line;
      throw e;
    }
  }

  function builtins(g) {
    g.define('print', (...a) => { out.push(a.map(stringify).join(' ')); return null; });
    g.define('max', (a, b) => Math.max(a, b));
    g.define('min', (a, b) => Math.min(a, b));
    g.define('abs', a => Math.abs(a));
    g.define('sqrt', a => Math.sqrt(a));
  }

  function runDart(src) {
    out = []; steps = 0;
    const prog = new Parser(tokenize(src)).program();
    const g = new Env(null);
    builtins(g);
    for (const s of prog) {
      if (s.k === 'fn') g.define(s.name, { fn: true, name: s.name, params: s.params, body: s.body, env: g });
    }
    const main = g.v.get('main');
    if (main && main.fn) {
      for (const s of prog) if (s.k === 'decl') exec(s, g);
      callUser(main, []);
    } else {
      for (const s of prog) if (s.k !== 'fn') exec(s, g);
    }
    return out.join('\n');
  }

  function run() {
    const outEl = document.getElementById('out');
    try {
      const r = runDart(document.getElementById('code').value);
      outEl.textContent = r || '(لا يوجد مخرجات)';
    } catch (e) {
      outEl.innerHTML = '';
      const t = document.createElement('div'); t.className = 'err';
      t.textContent = 'خطأ' + (e.line ? ' - السطر ' + e.line : '');
      const d = document.createElement('div'); d.textContent = e.message || String(e);
      outEl.appendChild(t); outEl.appendChild(d);
    }
  }

  document.getElementById('run').onclick = run;
  document.getElementById('reset').onclick = () => { document.getElementById('code').value = SAMPLE; };
  document.getElementById('code').value = SAMPLE;
</script>
</body>
</html>
''';

class DartPage extends StatefulWidget {
  const DartPage({super.key});

  @override
  State<DartPage> createState() => _DartPageState();
}

class _DartPageState extends State<DartPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_dartHtml, baseUrl: 'https://localhost/');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
