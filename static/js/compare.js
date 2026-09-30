(function(){'use strict';const root=document.getElementById('compare-root');if(!root)return;const fieldSizeSelect=document.getElementById('compare-field-size');const applicationSelect=document.getElementById('compare-application');const budgetSelect=document.getElementById('compare-budget');const resultsGrid=document.getElementById('compare-results');const cards=Array.from(resultsGrid?.querySelectorAll('.compare-pick')||[]);const emptyState=document.getElementById('compare-empty');function applyFilters(){const fieldSize=fieldSizeSelect?.value||'all';const application=applicationSelect?.value||'all';const budget=budgetSelect?.value||'all';let visibleCount=0;cards.forEach((card)=>{const cardFieldSize=card.dataset.fieldSize||'all';const cardApplication=card.dataset.application||'all';const cardBudget=card.dataset.budget||'all';const matchesFieldSize=fieldSize==='all'||cardFieldSize.split(',').map((t)=>t.trim()).includes(fieldSize);const matchesApplication=application==='all'||cardApplication.split(',').map((t)=>t.trim()).includes(application);const matchesBudget=budget==='all'||cardBudget.split(',').map((t)=>t.trim()).includes(budget);if(matchesFieldSize&&matchesApplication&&matchesBudget){card.style.display='';visibleCount++;}else{card.style.display='none';}});if(emptyState)emptyState.style.display=visibleCount===0?'block':'none';}
[fieldSizeSelect,applicationSelect,budgetSelect].forEach((el)=>{if(el)el.addEventListener('change',applyFilters);});const MAX=4;const selected=new Map();const bar=document.getElementById('compare-bar');const barThumbs=document.getElementById('compare-bar-thumbs');const barCount=document.getElementById('compare-bar-count');const clearBtn=document.getElementById('compare-clear');const viewBtn=document.getElementById('compare-view');const tableWrap=document.getElementById('compare-table-wrap');const table=document.getElementById('compare-table');function getCardData(card){let specs={};let featuresRich=[];try{specs=JSON.parse(card.dataset.specs||'{}');}catch(e){}
try{featuresRich=JSON.parse(card.dataset.featuresRich||'[]');}catch(e){}
return{slug:card.dataset.slug,name:card.dataset.name,tagline:card.dataset.tagline,image:card.dataset.image,url:card.dataset.url,specs:specs,features:featuresRich,applications:(card.dataset.applications||'').split(',').filter(Boolean),};}
function humanize(key){return key.replace(/-/g,' ').replace(/\b\w/g,(c)=>c.toUpperCase());}
function renderBar(){const count=selected.size;if(barCount)barCount.textContent=count;if(!bar)return;if(count===0){bar.hidden=true;tableWrap.hidden=true;return;}
bar.hidden=false;if(barThumbs){barThumbs.innerHTML='';selected.forEach((data)=>{const thumb=document.createElement('div');thumb.className='compare-bar-thumb';thumb.innerHTML=`
          <img src="${data.image}" alt="${data.name}">
          <span class="compare-bar-thumb-name">${data.name}</span>
          <button type="button" aria-label="Remove" data-remove="${data.slug}">×</button>
        `;barThumbs.appendChild(thumb);});barThumbs.querySelectorAll('[data-remove]').forEach((btn)=>{btn.addEventListener('click',(e)=>{e.stopPropagation();toggleProduct(btn.dataset.remove);});});}}
function renderTable(){if(!table)return;const items=Array.from(selected.values());if(items.length<1){tableWrap.hidden=true;return;}
tableWrap.hidden=false;const allSpecKeys=[];const seenKeys=new Set();items.forEach((it)=>{Object.keys(it.specs||{}).forEach((k)=>{if(!seenKeys.has(k)){seenKeys.add(k);allSpecKeys.push(k);}});});let html='';html+='<thead><tr><th></th>';items.forEach((it)=>{html+=`
        <th>
          <a href="${it.url}" class="compare-th-link">
            <div class="compare-th-image">
              <img src="${it.image}" alt="${it.name}" loading="lazy">
            </div>
            <strong>${it.name}</strong>
            <small>${it.tagline}</small>
          </a>
        </th>
      `;});html+='</tr></thead><tbody>';if(allSpecKeys.length>0){html+=`<tr class="compare-section-row"><td colspan="${items.length + 1}">Specifications</td></tr>`;allSpecKeys.forEach((key)=>{html+=`<tr><td class="compare-key">${humanize(key)}</td>`;items.forEach((it)=>{const value=it.specs[key];html+=`<td>${value ? value : '<span class="compare-dash">—</span>'}</td>`;});html+='</tr>';});}
html+=`<tr class="compare-section-row"><td colspan="${items.length + 1}">Key features</td></tr>`;html+='<tr><td class="compare-key">Features</td>';items.forEach((it)=>{let list='<span class="compare-dash">—</span>';if(it.features&&it.features.length){const rendered=it.features.map((f)=>{if(typeof f==='string'){return`<li>${humanize(f)}</li>`;}
const title=f.title?`<strong>${f.title}</strong>`:'';const desc=f.desc?`<span>${f.desc}</span>`:'';return`<li class="compare-feature-item">${title}${desc}</li>`;}).join('');list=`<ul class="compare-bullet">${rendered}</ul>`;}
html+=`<td>${list}</td>`;});html+='</tr>';html+='<tr><td class="compare-key">Applications</td>';items.forEach((it)=>{const list=it.applications.length?`<ul class="compare-bullet">${it.applications.map((a) => `<li>${humanize(a)}</li>`).join('')}</ul>`:'<span class="compare-dash">—</span>';html+=`<td>${list}</td>`;});html+='</tr>';html+=`<tr class="compare-cta-row"><td></td>`;items.forEach((it)=>{html+=`<td><a href="${it.url}" class="btn btn-primary btn-sm btn-arrow">View product</a></td>`;});html+='</tr>';html+='</tbody>';table.innerHTML=html;}
function toggleProduct(slug){const card=cards.find((c)=>c.dataset.slug===slug);if(!card)return;if(selected.has(slug)){selected.delete(slug);card.classList.remove('is-selected');}else{if(selected.size>=MAX){const btn=card.querySelector('.compare-toggle');if(btn){btn.classList.add('shake');setTimeout(()=>btn.classList.remove('shake'),400);}
return;}
selected.set(slug,getCardData(card));card.classList.add('is-selected');}
renderBar();renderTable();}
cards.forEach((card)=>{const btn=card.querySelector('.compare-toggle');if(!btn)return;btn.addEventListener('click',(e)=>{e.preventDefault();e.stopPropagation();toggleProduct(card.dataset.slug);});});if(clearBtn){clearBtn.addEventListener('click',()=>{selected.clear();cards.forEach((c)=>c.classList.remove('is-selected'));renderBar();renderTable();});}
if(viewBtn){viewBtn.addEventListener('click',(e)=>{if(selected.size===0){e.preventDefault();return;}
tableWrap.hidden=false;});}})();