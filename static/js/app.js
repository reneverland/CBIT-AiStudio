const $ = (s)=>document.querySelector(s);
const $$ = (s)=>document.querySelectorAll(s);

let mode = 'txt2img';
let ws;
let clientId = `ui_${Math.random().toString(36).slice(2)}`;
let lastImageURL = '';
let currentGenType = 'prompt';

function connectWS(){
  try{
    const url = `ws://${location.hostname}:8188/ws?clientId=${encodeURIComponent(clientId)}`;
    ws = new WebSocket(url);
    ws.onopen = ()=>console.log('WebSocket connected');
    ws.onclose = ()=>{ ws=null; console.log('WebSocket disconnected'); };
    ws.onerror = ()=>console.warn('WebSocket error');
    ws.onmessage = (ev)=>{
      try{
        const msg = JSON.parse(ev.data);
        if(msg.type==='progress'){
          const p = Math.max(0, Math.min(1, msg.data?.value ?? 0));
          const text = msg.data?.desc || '生成中';
          updateProgress(p, text);
        }
        // 监听任务开始事件，确保进度条重置
        else if(msg.type==='executing' && msg.data?.node){
          // 当开始执行第一个节点时，确保进度条已重置
          if(!window.taskStarted){
            window.taskStarted = true;
            updateProgress(0, '开始生成...');
          }
        }
        // 监听任务完成事件
        else if(msg.type==='executed'){
          // 任务完成后重置标志
          window.taskStarted = false;
        }
      }catch(e){}
    };
  }catch(e){
    console.warn('无法连接WebSocket，将使用轮询模式');
  }
}
connectWS();

async function fetchJSON(url, options={}){
  const res = await fetch(url, options);
  const text = await res.text();
  let data;
  try { data = JSON.parse(text); } catch (e) {
    throw new Error(`非JSON响应(${res.status}): ${text.slice(0,200)}`);
  }
  if(!res.ok || (data && data.status === 'error')){
    throw new Error((data && data.message) || `HTTP ${res.status}`);
  }
  return data;
}

function setMode(m){
  mode = m;
  $$('.mode').forEach(b=>b.classList.toggle('active', b.dataset.mode===m));
  
  // 控制各区域显隐
  const genTypeSection = $('#gen-type-section');
  const presetsSection = $('#presets-section');
  const negativeField = $('#negative-field');
  const uploadField = $('#upload-field');
  const maskField = $('#mask-field');
  const advancedSection = $('#advanced-section');
  const uploadLabel = $('#upload-label');
  
  // 重置显示状态
  genTypeSection.hidden = true;
  presetsSection.hidden = false;
  negativeField.hidden = false;
  uploadField.hidden = true;
  maskField.hidden = true;
  advancedSection.hidden = false;
  
  if(m === 'txt2img'){
    // 生图模式：显示生图类型选择，根据类型决定是否显示上传
    genTypeSection.hidden = false;
    const gt = currentGenType;
    if(gt === 'init'){
      uploadField.hidden = false;
      uploadLabel.textContent = '上传垫图';
    }
  } else if(m === 'face_swap'){
    // 换脸模式：只显示提示词和上传图片，隐藏其他
    uploadField.hidden = false;
    uploadLabel.textContent = '上传需要换脸的图片';
    negativeField.hidden = true;
    advancedSection.hidden = true;
  } else if(m === 'inpaint'){
    // 局部修复模式：显示上传和蒙版
    uploadField.hidden = false;
    maskField.hidden = false;
    uploadLabel.textContent = '上传需要修复的图片';
  }
}

// 生图类型切换
$$('input[name="genType"]').forEach(r=>r.addEventListener('change', e=>{
  currentGenType = e.target.value;
  setMode(mode);
}));

$$('.mode').forEach(b=>b.addEventListener('click',()=>setMode(b.dataset.mode)));

$$('.preset').forEach(b=>b.addEventListener('click',()=>{
  $('#prompt').value = b.dataset.prompt || '';
}));

$('#preset').addEventListener('change', e=>{
  const v = e.target.value;
  if(v==='fast'){ $('#steps').value=4; $('#cfg').value=3.0; }
  if(v==='fine'){ $('#steps').value=20; $('#cfg').value=5.5; }
});

async function uploadFile(input){
  if(!input.files||!input.files[0]) return null;
  const form = new FormData();
  form.append('file', input.files[0]);
  const data = await fetchJSON('/api/upload', {method:'POST', body: form});
  if(data.status!=='success') throw new Error(data.message||'上传失败');
  return data;
}

// 进度条控制
function showProgress(show){
  $('#progress').hidden = !show;
  $('#generate').disabled = show;
}

function initProgress(){
  // 确保进度条完全重置
  const fill = $('.progress-fill');
  const textEl = $('.progress-text');
  if(fill) {
    fill.style.width = '0%';
    fill.style.transition = 'none'; // 临时禁用动画
    setTimeout(() => {
      fill.style.transition = 'width 0.3s ease'; // 恢复动画
    }, 10);
  }
  if(textEl) textEl.textContent = '准备中...';
  showProgress(true);
}

function updateProgress(percent, text){
  const fill = $('.progress-fill');
  const textEl = $('.progress-text');
  if(fill) fill.style.width = `${Math.max(0, Math.min(100, percent * 100))}%`;
  if(textEl) textEl.textContent = text || '生成中...';
}

function finishProgress(){
  updateProgress(1, '生成完成');
  setTimeout(() => {
    showProgress(false);
    // 确保进度条完全重置，为下次生成做准备
    const fill = $('.progress-fill');
    if(fill) fill.style.width = '0%';
  }, 1500);
}

async function pollResult(pid){
  for(let i=0;i<60;i++){
    try{
      const d = await fetchJSON(`/api/result?prompt_id=${encodeURIComponent(pid)}`, {headers:{'Accept':'application/json'}});
      if(d.status==='success' && d.images && d.images.length){
        return d.images[0].url;
      }
    }catch(e){ /* 忽略重试 */ }
    await new Promise(rs=>setTimeout(rs, 1000));
  }
  throw new Error('获取结果超时');
}

$('#generate').addEventListener('click', async ()=>{
  try{
    // 重置任务标志和进度条
    window.taskStarted = false;
    // 隐藏之前的结果
    $('#result').hidden = true;
    showProgress(true);
    initProgress();
    
    let payload = { mode, client_id: clientId };
    
    if(mode==='txt2img'){
      payload.prompt = $('#prompt').value || '写实风，亚洲女生，自然光，清晰面部细节';
      payload.negative_prompt = $('#negative').value || '';
      payload.width = +$('#width').value;
      payload.height = +$('#height').value;
      payload.steps = +$('#steps').value;
      payload.guidance = +$('#cfg').value;
      const seed = $('#seed').value.trim();
      if(seed) payload.seed = +seed;
      
      if(currentGenType==='init'){
        const up = await uploadFile($('#file'));
        if(!up) throw new Error('请上传垫图');
        payload.image = up.path;
      }
    } else if(mode==='face_swap'){
      const up = await uploadFile($('#file'));
      if(!up) throw new Error('请上传需要换脸的图片');
      payload.image = up.path;
      payload.prompt = $('#prompt').value || '';
    } else if(mode==='inpaint'){
      const up = await uploadFile($('#file'));
      if(!up) throw new Error('请上传需要修复的图片');
      payload.image = up.path;
      
      // 若用户圈选了区域，导出 mask 并上传
      const maskBlob = await exportMaskIfAny();
      if(maskBlob){
        const form = new FormData();
        form.append('file', maskBlob, 'mask.png');
        const mu = await fetchJSON('/api/upload', {method:'POST', body: form});
        payload.mask = mu.path;
      }
      payload.prompt = $('#prompt').value || '';
    }
    
    const data = await fetchJSON('/api/generate', {
      method:'POST',
      headers:{'Content-Type':'application/json','Accept':'application/json','X-Client-Id': clientId},
      body: JSON.stringify(payload)
    });
    
    const pid = data.prompt_id;
    const url = await pollResult(pid);
    
    finishProgress();
    $('#result').hidden=false;
    $('#preview').src = url;
    lastImageURL = url;
    
  }catch(err){
    showProgress(false);
    alert(err.message||String(err));
  }
});

// 结果动作栏
$('#btn-ok').addEventListener('click', ()=>{
  alert('已保存，您可以继续新建任务。');
  $('#result').hidden = true;
});

$('#btn-face').addEventListener('click', ()=>{
  setMode('face_swap');
  $('#result').hidden = true;
  alert('请上传目标脸部照片，系统将把该脸替换到当前图像主体上');
});

// 局部修复圈选
let drawing = false;
let ctx, canvas, imgEl;
let maskDrawn = false;

function setupCanvas(){
  imgEl = $('#preview');
  canvas = $('#maskCanvas');
  const rect = imgEl.getBoundingClientRect();
  canvas.width = imgEl.naturalWidth;
  canvas.height = imgEl.naturalHeight;
  canvas.style.width = imgEl.clientWidth + 'px';
  canvas.style.height = imgEl.clientHeight + 'px';
  canvas.hidden = false;
  canvas.style.pointerEvents = 'auto';
  ctx = canvas.getContext('2d');
  ctx.clearRect(0,0,canvas.width,canvas.height);
  ctx.strokeStyle = 'rgba(255,0,0,0.8)';
  ctx.lineWidth = Math.max(8, Math.round(canvas.width/200));
  ctx.lineCap='round';
  ctx.lineJoin='round';
}

$('#btn-inpaint').addEventListener('click', ()=>{
  setMode('inpaint');
  $('#result').hidden = true;
  $('.mask-tools').hidden = false;
  $('#start-inpaint').hidden = false;
  $('#apply-inpaint').hidden = true;
  $('#cancel-inpaint').hidden = true;
});

$('#start-inpaint').addEventListener('click', ()=>{
  setupCanvas();
  maskDrawn = false;
  $('#apply-inpaint').hidden = false;
  $('#cancel-inpaint').hidden = false;
  $('#start-inpaint').hidden = true;
});

function getPos(e){
  const r = canvas.getBoundingClientRect();
  const x = (e.clientX - r.left) * (canvas.width / r.width);
  const y = (e.clientY - r.top) * (canvas.height / r.height);
  return {x,y};
}

// 画布事件
canvas?.addEventListener('mousedown', (e)=>{
  if(canvas.hidden) return;
  drawing = true;
  const p = getPos(e);
  ctx.beginPath();
  ctx.moveTo(p.x, p.y);
});

canvas?.addEventListener('mousemove', (e)=>{
  if(!drawing || canvas.hidden) return;
  const p = getPos(e);
  ctx.lineTo(p.x, p.y);
  ctx.stroke();
  maskDrawn = true;
});

canvas?.addEventListener('mouseup', ()=>{
  drawing = false;
});

canvas?.addEventListener('mouseleave', ()=>{
  drawing = false;
});

$('#cancel-inpaint').addEventListener('click', ()=>{
  if(canvas){ canvas.hidden = true; }
  $('.mask-tools').hidden = true;
  maskDrawn = false;
});

$('#apply-inpaint').addEventListener('click', async ()=>{
  if(!maskDrawn){
    alert('请先圈选需要修复的区域');
    return;
  }
  
  try{
    // 重置任务标志和进度条
    window.taskStarted = false;
    // 隐藏之前的结果
    $('#result').hidden = true;
    showProgress(true);
    initProgress();
    
    const maskBlob = await exportMaskIfAny();
    if(!maskBlob) throw new Error('无法导出蒙版');
    
    const form = new FormData();
    form.append('file', maskBlob, 'mask.png');
    const mu = await fetchJSON('/api/upload', {method:'POST', body: form});
    
    const payload = {
      mode: 'inpaint',
      client_id: clientId,
      image: lastImageURL.replace('/api/proxy/view?', ''), // 提取原始路径
      mask: mu.path,
      prompt: $('#prompt').value || '修复图像'
    };
    
    const data = await fetchJSON('/api/generate', {
      method:'POST',
      headers:{'Content-Type':'application/json','Accept':'application/json','X-Client-Id': clientId},
      body: JSON.stringify(payload)
    });
    
    const pid = data.prompt_id;
    const url = await pollResult(pid);
    
    finishProgress();
    $('#preview').src = url;
    lastImageURL = url;
    
    // 清理画布
    canvas.hidden = true;
    $('.mask-tools').hidden = true;
    maskDrawn = false;
    
  }catch(err){
    showProgress(false);
    alert(err.message||String(err));
  }
});

async function exportMaskIfAny(){
  if(!canvas || canvas.hidden || !maskDrawn) return null;
  return await new Promise((resolve)=> canvas.toBlob(b=>resolve(b), 'image/png'));
}

// 初始化
setMode('txt2img'); 