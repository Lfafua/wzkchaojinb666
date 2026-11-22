'use strict';
const $=id=>document.getElementById(id), names=['自由装机','维修委托','维修学堂','上门装机'];
const tips=['用入门库存组装第一台主机，也可以选购配件自由搭配。','接取工单，排查故障并通过联合压测。','观察症状、提交诊断，在装配台验证判断。','按客户预算选购硬件，完成装配并交付订单。'];
let choice=0,mode=0,state,loading=false,help=false;
window.forgeMobile=matchMedia('(pointer:coarse)').matches||innerWidth<761;
const cmd=(op,a='',b=0)=>window.forgeCommand?.(op,a,b);
const button=(text,fn)=>{const b=document.createElement('button');b.className='control';b.textContent=text;b.onclick=fn;return b};
const text=(id,t)=>$(id).textContent=t;
const marks={cpu:'▦',wrench:'⚒',book:'▤',case:'▣',power:'⏻',cube:'◇',reset:'⟲',list:'☷',move:'✥',help:'?'};
document.querySelectorAll('[data-icon]').forEach(n=>n.textContent=marks[n.dataset.icon]);
document.querySelectorAll('[data-mode]').forEach((b,i)=>b.onclick=()=>{choice=i;document.querySelectorAll('[data-mode]').forEach((x,j)=>{x.classList.toggle('active',i===j);x.setAttribute('aria-pressed',i===j)});text('modeDesc',tips[i])});
function resize(){const r=$('viewFrame').getBoundingClientRect();if(!r.width||!r.height)return;const k=Math.min(devicePixelRatio,window.forgeMobile?1.35:1.75,1200/r.width);for(const p of ['width','height']){const v=Math.round(r[p]*k);if($('canvas')[p]!==v)$('canvas')[p]=v}}
new ResizeObserver(resize).observe($('viewFrame'));
function page(name){document.querySelector('.benchLayout').dataset.page=name;document.querySelectorAll('#mobileTabs button').forEach(b=>b.setAttribute('aria-pressed',b.dataset.page===name));requestAnimationFrame(resize)}
document.querySelectorAll('#mobileTabs button').forEach(b=>b.onclick=()=>page(b.dataset.page));
function enter(){if(mode!==choice){mode=choice;cmd('mode',mode)}text('modeName',names[mode]);$('menu').hidden=true;$('menuFooter').hidden=true;$('workshop').hidden=false;page('view');scrollTo(0,0)}
function menu(){if(loading)return;$('workshop').hidden=true;$('menu').hidden=false;$('menuFooter').hidden=false}
$('home').onclick=e=>{e.preventDefault();menu()};$('backMenu').onclick=menu;
function widget(d){if(d.kind==='button'){const b=button(d.text,()=>cmd('button',d.id));b.disabled=d.disabled;return b}
if(d.kind==='choice'){const s=document.createElement('select');s.setAttribute('aria-label',d.choices[d.value]||'选择项目');d.choices.forEach((v,i)=>s.add(new Option(v,i)));s.selectedIndex=d.value;s.disabled=!!d.disabled;s.onchange=()=>cmd(d.op,d.id,+s.value);return s}
if(d.kind==='progress'){const p=document.createElement('progress');p.max=1;p.value=d.value;return p}const p=document.createElement('p');p.textContent=d.text;return p}
const keys=new Map();
function render(id,data,fn){let key=JSON.stringify(data);if(keys.get(id)===key)return;keys.set(id,key);const r=$(id);r.replaceChildren();fn(r)}
const controls=(id,list)=>render(id,list,n=>list.forEach(d=>n.append(widget(d))));
function dialog(d){if(help)return;render('dialogBody',d,n=>{const m=$('modal');if(!d.id){if(m.open)m.close();return}text('dialogTitle',d.title);n.className='modalContent';n.append(widget({text:d.message}));d.content.forEach(c=>n.append(widget(c)));$('dialogFoot').replaceChildren(button(d.ok==='OK'?'确定':d.ok,()=>cmd('confirm',d.id)));if(d.cancel)$('dialogFoot').prepend(button('取消',()=>cmd('dismiss',d.id)));if(!m.open)m.showModal()})}
function close(){if(help){help=false;$('modal').close();keys.delete('dialogBody');if(state)dialog(state.dialog)}else if(state?.dialog.id)cmd('dismiss',state.dialog.id)}
$('modal').oncancel=e=>{e.preventDefault();close()};$('closeDialog').onclick=close;
$('help').onclick=()=>{help=true;text('dialogTitle','操作指南');text('dialogBody','在配件架装入入门库存整套，在工作单连接三组供电，再开机自检。轻点选取、单指拖动旋转、双指缩放或平移。点保存可在同一浏览器读档。');$('dialogFoot').replaceChildren();$('modal').showModal()};
window.forgeReceive=raw=>{const first=!state;state=JSON.parse(raw);const s=state;
for(const [id,k] of Object.entries({balance:'balance',count:'count',shelfName:'shelfTitle',status:'status',viewTitle:'title',selection:'selection',matches:'matches'}))text(id,s[k]);
controls('fileTools',s.file);controls('cameraTools',s.camera);controls('actions',s.actions);controls('work',s.work.filter(v=>v.text!=='工作单'));controls('partFilter',[s.filter]);controls('pack',s.pack.id?[s.pack]:[]);
render('marketTabs',[s.tabs,s.market],n=>s.tabs.forEach((d,i)=>{const b=widget(d);b.setAttribute('aria-pressed',['','new','used','owned'][i]===s.market);n.append(b)}));
render('parts',[s.parts,s.selected],n=>{let at=0;function add(){for(const [id,t] of s.parts.slice(at,at+50)){const [name,...sub]=t.split('\n');const b=button(name,()=>{cmd('part',id);if(window.forgeMobile)page('view')});b.className='part'+(s.selected===id?' selected':'');const small=document.createElement('small');small.textContent=sub.join(' ');b.append(small);n.append(b)}at+=50;if(at<s.parts.length){const b=button('显示更多',()=>{b.remove();add()});n.append(b)}}add()});
render('offers',s.offers,n=>s.offers.forEach(o=>{const c=document.createElement('div');c.className='offer';c.append(widget({text:o.name+' '+o.caption}));o.controls.forEach(d=>c.append(widget(d)));n.append(c)}));dialog(s.dialog);
if(first){loading=false;$('start').disabled=false;$('loadInfo').hidden=true;queueMicrotask(enter)}};
$('search').oninput=e=>cmd('search',e.target.value);$('reset').onclick=()=>cmd('reset');text('hint',window.forgeMobile?'轻点选取 · 单指旋转 · 双指缩放或平移':'点击选取 · 拖动旋转 · 中键平移 · 滚轮缩放');
const area=$('gesture'),pts=new Map();let moved=false,pan=false,origin;
area.oncontextmenu=e=>e.preventDefault();area.onpointerdown=e=>{e.preventDefault();area.setPointerCapture(e.pointerId);pts.set(e.pointerId,[e.clientX,e.clientY]);if(pts.size===1){origin=[e.clientX,e.clientY];moved=false;pan=e.shiftKey||e.button===1}else moved=true};
const span=([a,b])=>Math.hypot(a[0]-b[0],a[1]-b[1]);
area.onpointermove=e=>{if(!pts.has(e.pointerId))return;const old=[...pts.values()],last=pts.get(e.pointerId),dx=e.clientX-last[0],dy=e.clientY-last[1];pts.set(e.pointerId,[e.clientX,e.clientY]);if(pts.size===2){const a=span(old),b=span([...pts.values()]);if(a>5&&b>5)cmd('zoom',a/b);cmd('pan',dx/2,dy/2)}else if(pts.size===1){if(Math.hypot(e.clientX-origin[0],e.clientY-origin[1])>4)moved=true;if(moved)cmd(pan?'pan':'orbit',dx,dy)}};
area.onpointerup=e=>{if(!moved&&pts.has(e.pointerId)&&e.button===0){const r=area.getBoundingClientRect();cmd('pick',(e.clientX-r.left)/r.width,(e.clientY-r.top)/r.height)}pts.delete(e.pointerId)};area.onpointercancel=area.onlostpointercapture=e=>pts.delete(e.pointerId);
area.addEventListener('wheel',e=>{e.preventDefault();cmd('zoom',Math.exp(Math.max(-180,Math.min(180,e.deltaY))*.0013))},{passive:false});area.onkeydown=e=>{const xy={ArrowRight:[10,0],ArrowLeft:[-10,0],ArrowUp:[0,-10],ArrowDown:[0,10]}[e.key];if(xy){e.preventDefault();cmd('orbit',...xy)}if(['+','=','-'].includes(e.key))cmd('zoom',e.key==='-'?1.12:.88)};
window.loadForgeWasm=async path=>{const r=await fetch(path+'.bin');if(!r.ok)throw Error('引擎下载失败');return new Response(r.body.pipeThrough(new DecompressionStream('gzip')),{headers:{'Content-Type':'application/wasm'}})};
$('start').onclick=async()=>{if(state){enter();return}if(loading)return;loading=true;$('start').disabled=true;$('loadInfo').hidden=false;text('loadText','正在加载约 11 MB 的游戏资源…');
try{await new Promise((ok,no)=>{const s=document.createElement('script');s.src='engine.js';s.onload=ok;s.onerror=no;document.head.append(s)});if(!Engine.isWebGLAvailable(2)||!window.DecompressionStream)throw Error('需要支持 WebGL 2 的新版浏览器，请开启硬件加速。');const engine=new Engine({executable:'engine',mainPack:'game.pck',canvas:$('canvas'),canvasResizePolicy:0,locale:'zh_CN',focusCanvas:false,persistentPaths:['/userfs'],args:['--rendering-method','gl_compatibility','res://Web.tscn']});await engine.startGame()}
catch(e){loading=false;text('loadText',e.message||'加载失败');$('start').disabled=false;$('start').lastElementChild.textContent='重新加载';$('start').onclick=()=>location.reload()}};
