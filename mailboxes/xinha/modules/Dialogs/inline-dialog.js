Xinha.Dialog=function(_1,_2,_3){
this.id={};
this.r_id={};
this.editor=_1;
this.document=document;
this.rootElem=document.createElement("div");
this.rootElem.className="dialog";
this.rootElem.style.position="absolute";
this.rootElem.style.display="none";
this.editor._framework.ed_cell.insertBefore(this.rootElem,this.editor._framework.ed_cell.firstChild);
this.rootElem.style.width=this.width=this.editor._framework.ed_cell.offsetWidth+"px";
this.rootElem.style.height=this.height=this.editor._framework.ed_cell.offsetHeight+"px";
var _4=this;
if(typeof _3=="function"){
this._lc=_3;
}else{
if(_3){
this._lc=function(_5){
return Xinha._lc(_5,_3);
};
}else{
this._lc=function(_6){
return _6;
};
}
}
_2=_2.replace(/\[([a-z0-9_]+)\]/ig,function(_7,id){
if(typeof _4.id[id]=="undefined"){
_4.id[id]=Xinha.uniq("Dialog");
_4.r_id[_4.id[id]]=id;
}
return _4.id[id];
}).replace(/<l10n>(.*?)<\/l10n>/ig,function(_9,_a){
return _4._lc(_a);
}).replace(/="_\((.*?)\)"/g,function(_b,_c){
return "=\""+_4._lc(_c)+"\"";
});
this.rootElem.innerHTML=_2;
this.editor.notifyOn("resize",function(e,_e){
_4.rootElem.style.width=_4.width=_4.editor._framework.ed_cell.offsetWidth+"px";
_4.rootElem.style.height=_4.height=_4.editor._framework.ed_cell.offsetHeight+"px";
_4.onresize();
});
};
Xinha.Dialog.prototype.onresize=function(){
return true;
};
Xinha.Dialog.prototype.show=function(_f){
if(Xinha.is_ie){
this._lastRange=this.editor._createRange(this.editor._getSelection());
}
if(typeof _f!="undefined"){
this.setValues(_f);
}
this._restoreTo=[this.editor._textArea.style.display,this.editor._iframe.style.visibility,this.editor.hidePanels()];
this.editor._textArea.style.display="none";
this.editor._iframe.style.visibility="hidden";
this.rootElem.style.display="";
};
Xinha.Dialog.prototype.hide=function(){
this.rootElem.style.display="none";
this.editor._textArea.style.display=this._restoreTo[0];
this.editor._iframe.style.visibility=this._restoreTo[1];
this.editor.showPanels(this._restoreTo[2]);
if(Xinha.is_ie){
this._lastRange.select();
}
this.editor.updateToolbar();
return this.getValues();
};
Xinha.Dialog.prototype.toggle=function(){
if(this.rootElem.style.display=="none"){
this.show();
}else{
this.hide();
}
};
Xinha.Dialog.prototype.setValues=function(_10){
for(var i in _10){
var _12=this.getElementsByName(i);
if(!_12){
continue;
}
for(var x=0;x<_12.length;x++){
var e=_12[x];
switch(e.tagName.toLowerCase()){
case "select":
for(var j=0;j<e.options.length;j++){
if(typeof _10[i]=="object"){
for(var k=0;k<_10[i].length;k++){
if(_10[i][k]==e.options[j].value){
e.options[j].selected=true;
}
}
}else{
if(_10[i]==e.options[j].value){
e.options[j].selected=true;
}
}
}
break;
case "textarea":
case "input":
switch(e.getAttribute("type")){
case "radio":
if(e.value==_10[i]){
e.checked=true;
}
break;
case "checkbox":
if(typeof _10[i]=="object"){
for(var j in _10[i]){
if(_10[i][j]==e.value){
e.checked=true;
}
}
}else{
if(_10[i]==e.value){
e.checked=true;
}
}
break;
default:
e.value=_10[i];
}
break;
default:
break;
}
}
}
};
Xinha.Dialog.prototype.getValues=function(){
var _17=[];
var _18=Xinha.collectionToArray(this.rootElem.getElementsByTagName("input")).append(Xinha.collectionToArray(this.rootElem.getElementsByTagName("textarea"))).append(Xinha.collectionToArray(this.rootElem.getElementsByTagName("select")));
for(var x=0;x<_18.length;x++){
var i=_18[x];
if(!(i.name&&this.r_id[i.name])){
continue;
}
if(typeof _17[this.r_id[i.name]]=="undefined"){
_17[this.r_id[i.name]]=null;
}
var v=_17[this.r_id[i.name]];
switch(i.tagName.toLowerCase()){
case "select":
if(i.multiple){
if(!v.push){
if(v!=null){
v=[v];
}else{
v=new Array();
}
}
for(var j=0;j<i.options.length;j++){
if(i.options[j].selected){
v.push(i.options[j].value);
}
}
}else{
if(i.selectedIndex>=0){
v=i.options[i.selectedIndex];
}
}
break;
case "textarea":
case "input":
default:
switch(i.type.toLowerCase()){
case "radio":
if(i.checked){
v=i.value;
break;
}
case "checkbox":
if(v==null){
if(this.getElementsByName(this.r_id[i.name]).length>1){
v=new Array();
}
}
if(i.checked){
if(v!=null&&typeof v=="object"&&v.push){
v.push(i.value);
}else{
v=i.value;
}
}
break;
default:
v=i.value;
break;
}
}
_17[this.r_id[i.name]]=v;
}
return _17;
};
Xinha.Dialog.prototype.getElementById=function(id){
return this.document.getElementById(this.id[id]?this.id[id]:id);
};
Xinha.Dialog.prototype.getElementsByName=function(_1e){
return this.document.getElementsByName(this.id[_1e]?this.id[_1e]:_1e);
};

