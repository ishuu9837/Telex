'use strict';
const reducedMotion=window.matchMedia('(prefers-reduced-motion: reduce)');
const tracks=[document.querySelector('#top-track'),document.querySelector('#demo-track')];
for(const track of tracks){const copy=track.firstElementChild.cloneNode(true);copy.setAttribute('aria-hidden','true');track.append(copy)}
function bindToggle(track,button,withText){let paused=reducedMotion.matches;const render=()=>{track.classList.toggle('paused',paused);button.setAttribute('aria-pressed',String(paused));button.setAttribute('aria-label',`${paused?'Play':'Pause'} ${withText?'demo':'notch animation'}`);button.innerHTML=withText?`${paused?'▶':'Ⅱ'} <span>${paused?'Play':'Pause'}</span>`:paused?'▶':'Ⅱ';button.disabled=reducedMotion.matches;if(reducedMotion.matches)button.setAttribute('aria-label','Animation disabled by Reduce Motion')};button.addEventListener('click',()=>{paused=!paused;render()});reducedMotion.addEventListener('change',()=>{paused=reducedMotion.matches;render()});render();return{reset(){paused=reducedMotion.matches;const duration=track.style.animationDuration;track.style.animation='none';void track.offsetHeight;track.style.animation='';track.style.animationDuration=duration;render()}}}
bindToggle(tracks[0],document.querySelector('#top-toggle'),false);
const demo=bindToggle(tracks[1],document.querySelector('#demo-toggle'),true);
document.querySelector('#demo-speed').addEventListener('change',event=>{tracks[1].style.animationDuration={slow:'65s',medium:'42s',fast:'25s'}[event.target.value]});
document.querySelector('#demo-restart').addEventListener('click',()=>demo.reset());
const dialog=document.querySelector('#download-dialog');
for(const button of document.querySelectorAll('[data-download]'))button.addEventListener('click',()=>dialog.showModal());
document.querySelector('.dialog-close').addEventListener('click',()=>dialog.close());
dialog.addEventListener('click',event=>{if(event.target===dialog){const r=dialog.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)dialog.close()}});

// Render the visitor's local date/time; system icons are illustrative, not device data.
function updateMacClocks(){const now=new Date();const date=new Intl.DateTimeFormat('en-GB',{weekday:'short',day:'numeric',month:'short'}).format(now).replaceAll(',','');const time=new Intl.DateTimeFormat('en-US',{hour:'numeric',minute:'2-digit',hour12:true}).format(now);for(const clock of document.querySelectorAll('.mac-clock')){clock.dateTime=now.toISOString();clock.textContent=date+' '+time}}
updateMacClocks();setInterval(updateMacClocks,30000);
