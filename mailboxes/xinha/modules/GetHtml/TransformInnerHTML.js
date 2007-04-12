function GetHtmlImplementation(_1){
this.editor=_1;
}
GetHtmlImplementation._pluginInfo={name:"GetHtmlImplementation TransformInnerHTML",version:"1.0",developer:"Nelson Bright",developer_url:"http://www.brightworkweb.com/",sponsor:"",sponsor_url:"",license:"htmlArea"};
HTMLArea.RegExpCache=[new RegExp().compile(/<\s*\/?([^\s\/>]+)[\s*\/>]/gi),new RegExp().compile(/(\s+)_moz[^=>]*=[^\s>]*/gi),new RegExp().compile(/\s*=\s*(([^'"][^>\s]*)([>\s])|"([^"]+)"|'([^']+)')/g),new RegExp().compile(/\/>/g),new RegExp().compile(/<(br|hr|img|input|link|meta|param|embed|area)((\s*\S*="[^"]*")*)>/g),new RegExp().compile(/(checked|compact|declare|defer|disabled|ismap|multiple|no(href|resize|shade|wrap)|readonly|selected)([\s>])/gi),new RegExp().compile(/(="[^']*)'([^'"]*")/),new RegExp().compile(/&(?=[^<]*>)/g),new RegExp().compile(/<\s+/g),new RegExp().compile(/\s+(\/)?>/g),new RegExp().compile(/\s{2,}/g),new RegExp().compile(/\s+([^=\s]+)((="[^"]+")|([\s>]))/g),new RegExp().compile(/\s+contenteditable(=[^>\s\/]*)?/gi),new RegExp().compile(/((href|src)=")([^\s]*)"/g),new RegExp().compile(/<\/?(div|p|h[1-6]|table|tr|td|th|ul|ol|li|blockquote|object|br|hr|img|embed|param|pre|script|html|head|body|meta|link|title|area|input|form|textarea|select|option)[^>]*>/g),new RegExp().compile(/<\/(div|p|h[1-6]|table|tr|ul|ol|blockquote|object|html|head|body|script|form|select)( [^>]*)?>/g),new RegExp().compile(/<(div|p|h[1-6]|table|tr|ul|ol|blockquote|object|html|head|body|script|form|select)( [^>]*)?>/g),new RegExp().compile(/<(td|th|li|option|br|hr|embed|param|pre|meta|link|title|area|input|textarea)[^>]*>/g),new RegExp().compile(/(^|<\/(pre|script)>)(\s|[^\s])*?(<(pre|script)[^>]*>|$)/g),new RegExp().compile(/(<pre[^>]*>)([\s\S])*?(<\/pre>)/g),new RegExp().compile(/(^|<!--[\s\S]*?-->)([\s\S]*?)(?=<!--[\s\S]*?-->|$)/g),new RegExp().compile(/\S*=""/g),new RegExp().compile(/<!--[\s\S]*?-->|<\?[\s\S]*?\?>|<\/?\w[^>]*>/g),new RegExp().compile(/(^|<\/script>)[\s\S]*?(<script[^>]*>|$)/g)];
HTMLArea.prototype.cleanHTML=function(_2){
var c=HTMLArea.RegExpCache;
_2=_2.replace(c[0],function(_4){
return _4.toLowerCase();
}).replace(c[1]," ").replace(c[12]," ").replace(c[2],"=\"$2$4$5\"$3").replace(c[21]," ").replace(c[11],function(_5,p1,p2){
return " "+p1.toLowerCase()+p2;
}).replace(c[3],">").replace(c[9],"$1>").replace(c[5],"$1=\"$1\"$3").replace(c[4],"<$1$2 />").replace(c[6],"$1$2").replace(c[8],"<").replace(c[10]," ");
if(HTMLArea.is_ie&&c[13].test(_2)){
_2=_2.replace(c[13],"$1"+this.stripBaseURL(RegExp.$3)+"\"");
}
if(this.config.only7BitPrintablesInURLs){
if(HTMLArea.is_ie){
c[13].test(_2);
}
if(c[13].test(_2)){
try{
_2=_2.replace(c[13],"$1"+decodeURIComponent(RegExp.$3).replace(/([^!-~]+)/g,function(_8){
return escape(_8);
})+"\"");
}
catch(e){
_2=_2.replace(c[13],"$1"+RegExp.$3.replace(/([^!-~]+)/g,function(_9){
return escape(_9);
})+"\"");
}
}
}
return _2;
};
HTMLArea.indent=function(s,_b){
HTMLArea.__nindent=0;
HTMLArea.__sindent="";
HTMLArea.__sindentChar=(typeof _b=="undefined")?"  ":_b;
var c=HTMLArea.RegExpCache;
if(HTMLArea.is_gecko){
s=s.replace(c[19],function(_d){
return _d.replace(/<br \/>/g,"\n");
});
}
s=s.replace(c[18],function(_e){
_e=_e.replace(c[20],function(st,$1,$2){
string=$2.replace(/[\n\r]/gi," ").replace(/\s+/gi," ").replace(c[14],function(str){
if(str.match(c[16])){
var s="\n"+HTMLArea.__sindent+str;
HTMLArea.__sindent+=HTMLArea.__sindentChar;
++HTMLArea.__nindent;
return s;
}else{
if(str.match(c[15])){
--HTMLArea.__nindent;
HTMLArea.__sindent="";
for(var i=HTMLArea.__nindent;i>0;--i){
HTMLArea.__sindent+=HTMLArea.__sindentChar;
}
return "\n"+HTMLArea.__sindent+str;
}else{
if(str.match(c[17])){
return "\n"+HTMLArea.__sindent+str;
}
}
}
return str;
});
return $1+string;
});
return _e;
});
s=s.replace(/^\s*/,"").replace(/ +\n/g,"\n").replace(/[\r\n]+<\/script>/g,"\n</script>");
return s;
};
HTMLArea.getHTML=function(_15,_16,_17){
var _18="";
var c=HTMLArea.RegExpCache;
if(_15.nodeType==11){
var div=document.createElement("div");
var _1b=_15.insertBefore(div,_15.firstChild);
for(j=_1b.nextSibling;j;j=j.nextSibling){
_1b.appendChild(j.cloneNode(true));
}
_18+=_1b.innerHTML.replace(c[23],function(_1c){
_1c=_1c.replace(c[22],function(tag){
if(/^<[!\?]/.test(tag)){
return tag;
}else{
return _17.cleanHTML(tag);
}
});
return _1c;
});
}else{
var _1e=(_15.nodeType==1)?_15.tagName.toLowerCase():"";
if(_16){
_18+="<"+_1e;
var _1f=_15.attributes;
for(i=0;i<_1f.length;++i){
var a=_1f.item(i);
if(!a.specified){
continue;
}
var _21=a.nodeName.toLowerCase();
var _22=a.nodeValue;
_18+=" "+_21+"=\""+_22+"\"";
}
_18+=">";
}
if(_1e=="html"){
innerhtml=_17._doc.documentElement.innerHTML;
}else{
innerhtml=_15.innerHTML;
}
_18+=innerhtml.replace(c[23],function(_23){
_23=_23.replace(c[22],function(tag){
if(/^<[!\?]/.test(tag)){
return tag;
}else{
if(!(_17.config.htmlRemoveTags&&_17.config.htmlRemoveTags.test(tag.replace(/<([^\s>\/]+)/,"$1")))){
return _17.cleanHTML(tag);
}else{
return "";
}
}
});
return _23;
});
if(HTMLArea.is_ie){
_18=_18.replace(/<li( [^>]*)?>/g,"</li><li$1>").replace(/(<(ul|ol)[^>]*>)[\s\n]*<\/li>/g,"$1").replace(/<\/li>([\s\n]*<\/li>)+/g,"</li>");
}
if(HTMLArea.is_gecko){
_18=_18.replace(/<br \/>\n$/,"");
}
if(_16){
_18+="</"+_1e+">";
}
_18=HTMLArea.indent(_18);
}
return _18;
};

