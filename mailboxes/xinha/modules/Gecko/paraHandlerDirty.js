EnterParagraphs._pluginInfo={name:"EnterParagraphs",origin:"Xinha Core",version:"$LastChangedRevision: 688 $".replace(/^[^:]*: (.*) \$$/,"$1"),developer:"The Xinha Core Developer Team",developer_url:"$HeadURL: http://svn.xinha.python-hosting.com/trunk/modules/Gecko/paraHandlerDirty.js $".replace(/^[^:]*: (.*) \$$/,"$1"),sponsor:"",sponsor_url:"",license:"htmlArea"};
function EnterParagraphs(_1){
this.editor=_1;
}
EnterParagraphs.prototype.onKeyPress=function(ev){
if(ev.keyCode==13&&!ev.shiftKey){
this.dom_checkInsertP();
Xinha._stopEvent(ev);
}
};
EnterParagraphs.prototype.dom_checkInsertP=function(){
var _3=this.editor;
var p,body;
var _5=_3.getSelection();
var _6=_3.createRange(_5);
if(!_6.collapsed){
_6.deleteContents();
}
_3.deactivateEditor();
var SC=_6.startContainer;
var SO=_6.startOffset;
var EC=_6.endContainer;
var EO=_6.endOffset;
if(SC==EC&&SC==body&&!SO&&!EO){
p=_3._doc.createTextNode(" ");
body.insertBefore(p,body.firstChild);
_6.selectNodeContents(p);
SC=_6.startContainer;
SO=_6.startOffset;
EC=_6.endContainer;
EO=_6.endOffset;
}
p=_3.getAllAncestors();
var _b=null;
body=_3._doc.body;
for(var i=0;i<p.length;++i){
if(Xinha.isParaContainer(p[i])){
break;
}else{
if(Xinha.isBlockElement(p[i])&&!(/body|html/i.test(p[i].tagName))){
_b=p[i];
break;
}
}
}
if(!_b){
var _d=_6.startContainer;
while(_d.parentNode&&!Xinha.isParaContainer(_d.parentNode)){
_d=_d.parentNode;
}
var _e=_d;
var _f=_d;
while(_e.previousSibling){
if(_e.previousSibling.tagName){
if(!Xinha.isBlockElement(_e.previousSibling)){
_e=_e.previousSibling;
}else{
break;
}
}else{
_e=_e.previousSibling;
}
}
while(_f.nextSibling){
if(_f.nextSibling.tagName){
if(!Xinha.isBlockElement(_f.nextSibling)){
_f=_f.nextSibling;
}else{
break;
}
}else{
_f=_f.nextSibling;
}
}
_6.setStartBefore(_e);
_6.setEndAfter(_f);
_6.surroundContents(_3._doc.createElement("p"));
_b=_6.startContainer.firstChild;
_6.setStart(SC,SO);
}
_6.setEndAfter(_b);
var r2=_6.cloneRange();
_5.removeRange(_6);
var df=r2.extractContents();
if(df.childNodes.length===0){
df.appendChild(_3._doc.createElement("p"));
df.firstChild.appendChild(_3._doc.createElement("br"));
}
if(df.childNodes.length>1){
var nb=_3._doc.createElement("p");
while(df.firstChild){
var s=df.firstChild;
df.removeChild(s);
nb.appendChild(s);
}
df.appendChild(nb);
}
if(!(/\S/.test(_b.innerHTML))){
_b.innerHTML="&nbsp;";
}
p=df.firstChild;
if(!(/\S/.test(p.innerHTML))){
p.innerHTML="<br />";
}
if((/^\s*<br\s*\/?>\s*$/.test(p.innerHTML))&&(/^h[1-6]$/i.test(p.tagName))){
df.appendChild(_3.convertNode(p,"p"));
df.removeChild(p);
}
var _14=_b.parentNode.insertBefore(df.firstChild,_b.nextSibling);
_3.activateEditor();
_5=_3.getSelection();
_5.removeAllRanges();
_5.collapse(_14,0);
_3.scrollToElement(_14);
};

