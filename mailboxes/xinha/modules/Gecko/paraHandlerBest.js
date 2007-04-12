EnterParagraphs._pluginInfo={name:"EnterParagraphs",version:"1.0",developer:"Adam Wright",developer_url:"http://www.hipikat.org/",sponsor:"The University of Western Australia",sponsor_url:"http://www.uwa.edu.au/",license:"htmlArea"};
EnterParagraphs.prototype._whiteSpace=/^\s*$/;
EnterParagraphs.prototype._pExclusions=/^(address|blockquote|body|dd|div|dl|dt|fieldset|form|h1|h2|h3|h4|h5|h6|hr|li|noscript|ol|p|pre|table|ul)$/i;
EnterParagraphs.prototype._pContainers=/^(body|del|div|fieldset|form|ins|map|noscript|object|td|th)$/i;
EnterParagraphs.prototype._pBreak=/^(address|pre|blockquote)$/i;
EnterParagraphs.prototype._permEmpty=/^(area|base|basefont|br|col|frame|hr|img|input|isindex|link|meta|param)$/i;
EnterParagraphs.prototype._elemSolid=/^(applet|br|button|hr|img|input|table)$/i;
EnterParagraphs.prototype._pifySibling=/^(address|blockquote|del|div|dl|fieldset|form|h1|h2|h3|h4|h5|h6|hr|ins|map|noscript|object|ol|p|pre|table|ul|)$/i;
EnterParagraphs.prototype._pifyForced=/^(ul|ol|dl|table)$/i;
EnterParagraphs.prototype._pifyParent=/^(dd|dt|li|td|th|tr)$/i;
function EnterParagraphs(_1){
this.editor=_1;
if(Xinha.is_gecko){
this.onKeyPress=this.__onKeyPress;
}
}
EnterParagraphs.prototype.name="EnterParagraphs";
EnterParagraphs.prototype.insertAdjacentElement=function(_2,_3,el){
if(_3=="BeforeBegin"){
_2.parentNode.insertBefore(el,_2);
}else{
if(_3=="AfterEnd"){
_2.nextSibling?_2.parentNode.insertBefore(el,_2.nextSibling):_2.parentNode.appendChild(el);
}else{
if(_3=="AfterBegin"&&_2.firstChild){
_2.insertBefore(el,_2.firstChild);
}else{
if(_3=="BeforeEnd"||_3=="AfterBegin"){
_2.appendChild(el);
}
}
}
}
};
EnterParagraphs.prototype.forEachNodeUnder=function(_5,_6,_7,_8){
var _9,end;
if(_5.nodeType==11&&_5.firstChild){
_9=_5.firstChild;
end=_5.lastChild;
}else{
_9=end=_5;
}
while(end.lastChild){
end=end.lastChild;
}
return this.forEachNode(_9,end,_6,_7,_8);
};
EnterParagraphs.prototype.forEachNode=function(_a,_b,_c,_d,_e){
var _f=function(_10,_11){
return (_11=="ltr"?_10.nextSibling:_10.previousSibling);
};
var _12=function(_13,_14){
return (_14=="ltr"?_13.firstChild:_13.lastChild);
};
var _15,lookup,fnReturnVal;
var _16=_e;
var _17=false;
while(_15!=_d=="ltr"?_b:_a){
if(!_15){
_15=_d=="ltr"?_a:_b;
}else{
if(_12(_15,_d)){
_15=_12(_15,_d);
}else{
if(_f(_15,_d)){
_15=_f(_15,_d);
}else{
lookup=_15;
while(!_f(lookup,_d)&&lookup!=(_d=="ltr"?_b:_a)){
lookup=lookup.parentNode;
}
_15=(_f(lookup,_d)?_f(lookup,_d):lookup);
}
}
}
_17=(_15==(_d=="ltr"?_b:_a));
switch(_c){
case "cullids":
fnReturnVal=this._fenCullIds(_15,_16);
break;
case "find_fill":
fnReturnVal=this._fenEmptySet(_15,_16,_c,_17);
break;
case "find_cursorpoint":
fnReturnVal=this._fenEmptySet(_15,_16,_c,_17);
break;
}
if(fnReturnVal[0]){
return fnReturnVal[1];
}
if(_17){
break;
}
if(fnReturnVal[1]){
_16=fnReturnVal[1];
}
}
return false;
};
EnterParagraphs.prototype._fenEmptySet=function(_18,_19,_1a,_1b){
if(!_19&&!_18.firstChild){
_19=_18;
}
if((_18.nodeType==1&&this._elemSolid.test(_18.nodeName))||(_18.nodeType==3&&!this._whiteSpace.test(_18.nodeValue))||(_18.nodeType!=1&&_18.nodeType!=3)){
switch(_1a){
case "find_fill":
return new Array(true,false);
break;
case "find_cursorpoint":
return new Array(true,_18);
break;
}
}
if(_1b){
return new Array(true,_19);
}
return new Array(false,_19);
};
EnterParagraphs.prototype._fenCullIds=function(_1c,_1d,_1e){
if(_1d.id){
_1e[_1d.id]?_1d.id="":_1e[_1d.id]=true;
}
return new Array(false,_1e);
};
EnterParagraphs.prototype.processSide=function(rng,_20){
var _21=function(_22,_23){
return (_23=="left"?_22.previousSibling:_22.nextSibling);
};
var _24=_20=="left"?rng.startContainer:rng.endContainer;
var _25=_20=="left"?rng.startOffset:rng.endOffset;
var _26,start=_24;
while(start.nodeType==1&&!this._permEmpty.test(start.nodeName)){
start=(_25?start.lastChild:start.firstChild);
}
while(_26=_26?(_21(_26,_20)?_21(_26,_20):_26.parentNode):start){
if(_21(_26,_20)){
if(this._pExclusions.test(_21(_26,_20).nodeName)){
return this.processRng(rng,_20,_26,_21(_26,_20),(_20=="left"?"AfterEnd":"BeforeBegin"),true,false);
}
}else{
if(this._pContainers.test(_26.parentNode.nodeName)){
return this.processRng(rng,_20,_26,_26.parentNode,(_20=="left"?"AfterBegin":"BeforeEnd"),true,false);
}else{
if(this._pExclusions.test(_26.parentNode.nodeName)){
if(this._pBreak.test(_26.parentNode.nodeName)){
return this.processRng(rng,_20,_26,_26.parentNode,(_20=="left"?"AfterBegin":"BeforeEnd"),false,(_20=="left"?true:false));
}else{
return this.processRng(rng,_20,(_26=_26.parentNode),(_21(_26,_20)?_21(_26,_20):_26.parentNode),(_21(_26,_20)?(_20=="left"?"AfterEnd":"BeforeBegin"):(_20=="left"?"AfterBegin":"BeforeEnd")),false,false);
}
}
}
}
}
};
EnterParagraphs.prototype.processRng=function(rng,_28,_29,_2a,_2b,_2c,_2d){
var _2e=_28=="left"?rng.startContainer:rng.endContainer;
var _2f=_28=="left"?rng.startOffset:rng.endOffset;
var _30=this.editor;
var _31=_30._doc.createRange();
_31.selectNode(_29);
if(_28=="left"){
_31.setEnd(_2e,_2f);
rng.setStart(_31.startContainer,_31.startOffset);
}else{
if(_28=="right"){
_31.setStart(_2e,_2f);
rng.setEnd(_31.endContainer,_31.endOffset);
}
}
var cnt=_31.cloneContents();
this.forEachNodeUnder(cnt,"cullids","ltr",this.takenIds,false,false);
var _33,pifyOffset,fill;
_33=_28=="left"?(_31.endContainer.nodeType==3?true:false):(_31.startContainer.nodeType==3?false:true);
pifyOffset=_33?_31.startOffset:_31.endOffset;
_33=_33?_31.startContainer:_31.endContainer;
if(this._pifyParent.test(_33.nodeName)&&_33.parentNode.childNodes.item(0)==_33){
while(!this._pifySibling.test(_33.nodeName)){
_33=_33.parentNode;
}
}
if(cnt.nodeType==11&&!cnt.firstChild){
if(_33.nodeName!="BODY"||(_33.nodeName=="BODY"&&pifyOffset!=0)){
cnt.appendChild(_30._doc.createElement(_33.nodeName));
}
}
fill=this.forEachNodeUnder(cnt,"find_fill","ltr",false);
if(fill&&this._pifySibling.test(_33.nodeName)&&((pifyOffset==0)||(pifyOffset==1&&this._pifyForced.test(_33.nodeName)))){
_29=_30._doc.createElement("p");
_29.innerHTML="&nbsp;";
if((_28=="left")&&_33.previousSibling){
return new Array(_33.previousSibling,"AfterEnd",_29);
}else{
if((_28=="right")&&_33.nextSibling){
return new Array(_33.nextSibling,"BeforeBegin",_29);
}else{
return new Array(_33.parentNode,(_28=="left"?"AfterBegin":"BeforeEnd"),_29);
}
}
}
if(fill){
if(fill.nodeType==3){
fill=_30._doc.createDocumentFragment();
}
if((fill.nodeType==1&&!this._elemSolid.test())||fill.nodeType==11){
var _34=_30._doc.createElement("p");
_34.innerHTML="&nbsp;";
fill.appendChild(_34);
}else{
var _34=_30._doc.createElement("p");
_34.innerHTML="&nbsp;";
fill.parentNode.insertBefore(parentNode,fill);
}
}
if(fill){
_29=fill;
}else{
_29=(_2c||(cnt.nodeType==11&&!cnt.firstChild))?_30._doc.createElement("p"):_30._doc.createDocumentFragment();
_29.appendChild(cnt);
}
if(_2d){
_29.appendChild(_30._doc.createElement("br"));
}
return new Array(_2a,_2b,_29);
};
EnterParagraphs.prototype.isNormalListItem=function(rng){
var _36,listNode;
_36=rng.startContainer;
if((typeof _36.nodeName!="undefined")&&(_36.nodeName.toLowerCase()=="li")){
listNode=_36;
}else{
if((typeof _36.parentNode!="undefined")&&(typeof _36.parentNode.nodeName!="undefined")&&(_36.parentNode.nodeName.toLowerCase()=="li")){
listNode=_36.parentNode;
}else{
return false;
}
}
if(!listNode.previousSibling){
if(rng.startOffset==0){
return false;
}
}
return true;
};
EnterParagraphs.prototype.__onKeyPress=function(ev){
if(ev.keyCode==13&&!ev.shiftKey&&this.editor._iframe.contentWindow.getSelection){
return this.handleEnter(ev);
}
};
EnterParagraphs.prototype.handleEnter=function(ev){
var _39;
var sel=this.editor.getSelection();
var rng=this.editor.createRange(sel);
if(this.isNormalListItem(rng)){
return true;
}
this.takenIds=new Object();
var _3c=this.processSide(rng,"left");
var _3d=this.processSide(rng,"right");
_39=_3d[2];
sel.removeAllRanges();
rng.deleteContents();
var _3e=this.forEachNodeUnder(_39,"find_cursorpoint","ltr",false,true);
if(!_3e){
alert("INTERNAL ERROR - could not find place to put cursor after ENTER");
}
if(_3c){
this.insertAdjacentElement(_3c[0],_3c[1],_3c[2]);
}
if(_3d&&_3d.nodeType!=1){
this.insertAdjacentElement(_3d[0],_3d[1],_3d[2]);
}
if((_3e)&&(this._permEmpty.test(_3e.nodeName))){
var _3f=0;
while(_3e.parentNode.childNodes.item(_3f)!=_3e){
_3f++;
}
sel.collapse(_3e.parentNode,_3f);
}else{
try{
sel.collapse(_3e,0);
if(_3e.nodeType==3){
_3e=_3e.parentNode;
}
this.editor.scrollToElement(_3e);
}
catch(e){
}
}
this.editor.updateToolbar();
Xinha._stopEvent(ev);
return true;
};

