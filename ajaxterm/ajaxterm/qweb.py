#!/usr/bin/python2.3
#
# vim:set et ts=4 fdc=0 fdn=2 fdl=0:
#
# There are no blank lines between blocks beacause i use folding from:
# http://www.vim.org/scripts/script.php?script_id=515
#

"""= QWeb Framework =

== What is QWeb ? ==

QWeb is a python based [http://www.python.org/doc/peps/pep-0333/ WSGI]
compatible web framework, it provides an infratructure to quickly build web
applications consisting of:

 * A lightweight request handler (QWebRequest)
 * An xml templating engine (QWebXml and QWebHtml)
 * A simple name based controler (qweb_control)
 * A standalone WSGI Server (QWebWSGIServer)
 * A cgi and fastcgi WSGI wrapper (taken from flup)
 * A startup function that starts cgi, factgi or standalone according to the
   evironement (qweb_autorun).

QWeb applications are runnable in standalone mode (from commandline), via
FastCGI, Regular CGI or by any python WSGI compliant server.

QWeb doesn't provide any database access but it integrates nicely with ORMs
such as SQLObject, SQLAlchemy or plain DB-API.

Written by Antony Lesuisse (email al AT udev.org)

Homepage: http://antony.lesuisse.org/qweb/trac/

Forum: [http://antony.lesuisse.org/qweb/forum/viewforum.php?id=1 Forum]

== Quick Start (for Linux, MacOS X and cygwin) ==

Make sure you have at least python 2.3 installed and run the following commands:

{{{
$ wget http://antony.lesuisse.org/qweb/files/QWeb-0.7.tar.gz
$ tar zxvf QWeb-0.7.tar.gz
$ cd QWeb-0.7/examples/blog
$ ./blog.py
}}}

And point your browser to http://localhost:8080/

You may also try AjaxTerm which uses qweb request handler.

== Download ==

 * Version 0.7:
   * Source [/qweb/files/QWeb-0.7.tar.gz QWeb-0.7.tar.gz]
   * Python 2.3 Egg [/qweb/files/QWeb-0.7-py2.3.egg QWeb-0.7-py2.3.egg]
   * Python 2.4 Egg [/qweb/files/QWeb-0.7-py2.4.egg QWeb-0.7-py2.4.egg]

 * [/qweb/trac/browser Browse the source repository]

== Documentation ==

 * [/qweb/trac/browser/trunk/README.txt?format=raw Read the included documentation] 
 * QwebTemplating

== Mailin-list ==

 * Forum: [http://antony.lesuisse.org/qweb/forum/viewforum.php?id=1 Forum]
 * No mailing-list exists yet, discussion should happen on: [http://mail.python.org/mailman/listinfo/web-sig web-sig] [http://mail.python.org/pipermail/web-sig/ archives]

QWeb Components:
----------------

QWeb also feature a simple components api, that enables developers to easily
produces reusable components.

Default qweb components:

    - qweb_static:
        A qweb component to serve static content from the filesystem or from
        zipfiles.

    - qweb_dbadmin:
        scaffolding for sqlobject

License
-------
qweb/fcgi.py wich is BSD-like from saddi.com.
Everything else is put in the public domain.


TODO
----
    Announce QWeb to python-announce-list@python.org web-sig@python.org
    qweb_core
        rename request methods into
            request_save_files
            response_404
            response_redirect
            response_download
        request callback_generator, callback_function ?
        wsgi callback_server_local
        xml tags explicitly call render_attributes(t_att)?
        priority form-checkbox over t-value (for t-option)

"""

import BaseHTTPServer,SocketServer,Cookie
import cgi,datetime,email,email.Message,errno,gzip,os,random,re,socket,sys,tempfile,time,types,urllib,urlparse,xml.dom
try:
    import cPickle as pickle
except ImportError:
    import pickle
try:
    import cStringIO as StringIO
except ImportError:
    import StringIO

#----------------------------------------------------------
# Qweb Xml t-raw t-esc t-if t-foreach t-set t-call t-trim
#----------------------------------------------------------
class QWebEval:
    def __init__(self,data):
        self.data=data
    def __getitem__(self,expr):
        if self.data.has_key(expr):
            return self.data[expr]
        r=None
        try:
            r=eval(expr,self.data)
        except NameError,e:
            pass
        except AttributeError,e:
            pass
        except Exception,e:
            print "qweb: expression error '%s' "%expr,e
        if self.data.has_key("__builtins__"):
            del self.data["__builtins__"]
        return r
    def eval_object(self,expr):
        return self[expr]
    def eval_str(self,expr):
        if expr=="0":
            return self.data[0]
        if isinstance(self[expr],unicode):
            return self[expr].encode("utf8")
        return str(self[expr])
    def eval_format(self,expr):
        try:
            return str(expr%self)
        except:
            return "qweb: format error '%s' "%expr
#       if isinstance(r,unicode):
#           return r.encode("utf8")
    def eval_bool(self,expr):
        if self.eval_object(expr):
            return 1
        else:
            return 0
class QWebXml:
    """QWeb Xml templating engine
    
    The templating engine use a very simple syntax, "magic" xml attributes, to
    produce any kind of texutal output (even non-xml).
    
    QWebXml:
        the template engine core implements the basic magic attributes:
    
        t-att t-raw t-esc t-if t-foreach t-set t-call t-trim
    
    """
    def __init__(self,x=None,zipname=None):
        self.node=xml.dom.Node
        self._t={}
        self._render_tag={}
        prefix='render_tag_'
        for i in [j for j in dir(self) if j.startswith(prefix)]:
            name=i[len(prefix):].replace('_','-')
            self._render_tag[name]=getattr(self.__class__,i)

        self._render_att={}
        prefix='render_att_'
        for i in [j for j in dir(self) if j.startswith(prefix)]:
            name=i[len(prefix):].replace('_','-')
            self._render_att[name]=getattr(self.__class__,i)

        if x!=None:
            if zipname!=None:
                import zipfile
                zf=zipfile.ZipFile(zipname, 'r')
                self.add_template(zf.read(x))
            else:
                self.add_template(x)
    def register_tag(self,tag,func):
        self._render_tag[tag]=func
    def add_template(self,x):
        if hasattr(x,'documentElement'):
            dom=x
        elif x.startswith("<?xml"):
            import xml.dom.minidom
            dom=xml.dom.minidom.parseString(x)
        else:
            import xml.dom.minidom
            dom=xml.dom.minidom.parse(x)
        for n in dom.documentElement.childNodes:
            if n.nodeName=="t":
                self._t[str(n.getAttribute("t-name"))]=n
    def get_template(self,name):
        return self._t[name]

    def eval_object(self,expr,v):
        return QWebEval(v).eval_object(expr)
    def eval_str(self,expr,v):
        return QWebEval(v).eval_str(expr)
    def eval_format(self,expr,v):
        return QWebEval(v).eval_format(expr)
    def eval_bool(self,expr,v):
        return QWebEval(v).eval_bool(expr)

    def render(self,tname,v={},out=None):
        if self._t.has_key(tname):
            return self.render_node(self._t[tname],v)
        else:
            return 'qweb: template "%s" not found'%tname
    def render_node(self,e,v):
        r=""
        if e.nodeType==self.node.TEXT_NODE or e.nodeType==self.node.CDATA_SECTION_NODE:
            r=e.data.encode("utf8")
        elif e.nodeType==self.node.ELEMENT_NODE:
            pre=""
            g_att=""
            t_render=None
            t_att={}
            for (an,av) in e.attributes.items():
                an=str(an)
                if isinstance(av,types.UnicodeType):
                    av=av.encode("utf8")
                else:
                    av=av.nodeValue.encode("utf8")
                if an.startswith("t-"):
                    for i in self._render_att:
                        if an[2:].startswith(i):
                            g_att+=self._render_att[i](self,e,an,av,v)
                            break
                    else:
                        if self._render_tag.has_key(an[2:]):
                            t_render=an[2:]
                        t_att[an[2:]]=av
                else:
                    g_att+=' %s="%s"'%(an,cgi.escape(av,1));
            if t_render:
                if self._render_tag.has_key(t_render):
                    r=self._render_tag[t_render](self,e,t_att,g_att,v)
            else:
                r=self.render_element(e,g_att,v,pre,t_att.get("trim",0))
        return r
    def render_element(self,e,g_att,v,pre="",trim=0):
        g_inner=[]
        for n in e.childNodes:
            g_inner.append(self.render_node(n,v))
        name=str(e.nodeName)
        inner="".join(g_inner)
        if trim==0:
            pass
        elif trim=='left':
            inner=inner.lstrip()
        elif trim=='right':
            inner=inner.rstrip()
        elif trim=='both':
            inner=inner.strip()
        if name=="t":
            return inner
        elif len(inner):
            return "<%s%s>%s%s</%s>"%(name,g_att,pre,inner,name)
        else:
            return "<%s%s/>"%(name,g_att)

    # Attributes
    def render_att_att(self,e,an,av,v):
        if an.startswith("t-attf-"):
            att,val=an[7:],self.eval_format(av,v)
        elif an.startswith("t-att-"):
            att,val=(an[6:],self.eval_str(av,v))
        else:
            att,val=self.eval_object(av,v)
        return ' %s="%s"'%(att,cgi.escape(val,1))

    # Tags
    def render_tag_raw(self,e,t_att,g_att,v):
        return self.eval_str(t_att["raw"],v)
    def render_tag_rawf(self,e,t_att,g_att,v):
        return self.eval_format(t_att["rawf"],v)
    def render_tag_esc(self,e,t_att,g_att,v):
        return cgi.escape(self.eval_str(t_att["esc"],v))
    def render_tag_escf(self,e,t_att,g_att,v):
        return cgi.escape(self.eval_format(t_att["escf"],v))
    def render_tag_foreach(self,e,t_att,g_att,v):
        expr=t_att["foreach"]
        enum=self.eval_object(expr,v)
        if enum!=None:
            var=t_att.get('as',expr).replace('.','_')
            d=v.copy()
            size=-1
            if isinstance(enum,types.ListType):
                size=len(enum)
            elif isinstance(enum,types.TupleType):
                size=len(enum)
            elif hasattr(enum,'count'):
                size=enum.count()
            d["%s_size"%var]=size
            d["%s_all"%var]=enum
            index=0
            ru=[]
            for i in enum:
                d["%s_value"%var]=i
                d["%s_index"%var]=index
                d["%s_first"%var]=index==0
                d["%s_even"%var]=index%2
                d["%s_odd"%var]=(index+1)%2
                d["%s_last"%var]=index+1==size
                if index%2:
                    d["%s_parity"%var]='odd'
                else:
                    d["%s_parity"%var]='even'
                if isinstance(i,types.DictType):
                    d.update(i)
                else:
                    d[var]=i
                ru.append(self.render_element(e,g_att,d))
                index+=1
            return "".join(ru)
        else:
            return "qweb: t-foreach %s not found."%expr
    def render_tag_if(self,e,t_att,g_att,v):
        if self.eval_bool(t_att["if"],v):
            return self.render_element(e,g_att,v)
        else:
            return ""
    def render_tag_call(self,e,t_att,g_att,v):
        # TODO t-prefix
        if t_att.has_key("import"):
            d=v
        else:
            d=v.copy()
        d[0]=self.render_element(e,g_att,d)
        return self.render(t_att["call"],d)
    def render_tag_set(self,e,t_att,g_att,v):
        if t_att.has_key("eval"):
            v[t_att["set"]]=self.eval_object(t_att["eval"],v)
        else:
            v[t_att["set"]]=self.render_element(e,g_att,v)
        return ""

#----------------------------------------------------------
# QWeb HTML (+deprecated QWebFORM and QWebOLD)
#----------------------------------------------------------
class QWebURL:
    """ URL helper
    assert req.PATH_INFO== "/site/admin/page_edit"
    u = QWebURL(root_path="/site/",req_path=req.PATH_INFO)
    s=u.url2_href("user/login",{'a':'1'})
    assert s=="../user/login?a=1"
    
    """
    def __init__(self, root_path="/", req_path="/",defpath="",defparam={}):
        self.defpath=defpath
        self.defparam=defparam
        self.root_path=root_path
        self.req_path=req_path
        self.req_list=req_path.split("/")[:-1]
        self.req_len=len(self.req_list)
    def decode(self,s):
        h={}
        for k,v in cgi.parse_qsl(s,1):
            h[k]=v
        return h
    def encode(self,h):
        return urllib.urlencode(h.items())
    def request(self,req):
        return req.REQUEST
    def copy(self,path=None,param=None):
        npath=self.defpath
        if path:
            npath=path
        nparam=self.defparam.copy()
        if param:
            nparam.update(param)
        return QWebURL(self.root_path,self.req_path,npath,nparam)
    def path(self,path=''):
        if not path:
            path=self.defpath
        pl=(self.root_path+path).split('/')
        i=0
        for i in range(min(len(pl), self.req_len)):
            if pl[i]!=self.req_list[i]:
                break
        else:
            i+=1
        dd=self.req_len-i
        if dd<0:
            dd=0
        return '/'.join(['..']*dd+pl[i:])
    def href(self,path='',arg={}):
        p=self.path(path)
        tmp=self.defparam.copy()
        tmp.update(arg)
        s=self.encode(tmp)
        if len(s):
            return p+"?"+s
        else:
            return p
    def form(self,path='',arg={}):
        p=self.path(path)
        tmp=self.defparam.copy()
        tmp.update(arg)
        r=''.join(['<input type="hidden" name="%s" value="%s"/>'%(k,cgi.escape(str(v),1)) for k,v in tmp.items()])
        return (p,r)
class QWebField:
    def __init__(self,name=None,default="",check=None):
        self.name=name
        self.default=default
        self.check=check
        # optional attributes
        self.type=None
        self.trim=1
        self.required=1
        self.cssvalid="form_valid"
        self.cssinvalid="form_invalid"
        # set by addfield
        self.form=None
        # set by processing
        self.input=None
        self.css=None
        self.value=None
        self.valid=None
        self.invalid=None
        self.validate(1)
    def validate(self,val=1,update=1):
        if val:
            self.valid=1
            self.invalid=0
            self.css=self.cssvalid
        else:
            self.valid=0
            self.invalid=1
            self.css=self.cssinvalid
        if update and self.form:
            self.form.update()
    def invalidate(self,update=1):
        self.validate(0,update)
class QWebForm:
    class QWebFormF:
        pass
    def __init__(self,e=None,arg=None,default=None):
        self.fields={}
        # all fields have been submitted
        self.submitted=False
        self.missing=[]
        # at least one field is invalid or missing
        self.invalid=False
        self.error=[]
        # all fields have been submitted and are valid
        self.valid=False
        # fields under self.f for convenience
        self.f=self.QWebFormF()
        if e:
            self.add_template(e)
        # assume that the fields are done with the template
        if default:
            self.set_default(default,e==None)
        if arg!=None:
            self.process_input(arg)
    def __getitem__(self,k):
        return self.fields[k]
    def set_default(self,default,add_missing=1):
        for k,v in default.items():
            if self.fields.has_key(k):
                self.fields[k].default=str(v)
            elif add_missing:
                self.add_field(QWebField(k,v))
    def add_field(self,f):
        self.fields[f.name]=f
        f.form=self
        setattr(self.f,f.name,f)
    def add_template(self,e):
        att={}
        for (an,av) in e.attributes.items():
            an=str(an)
            if an.startswith("t-"):
                att[an[2:]]=av.encode("utf8")
        for i in ["form-text", "form-password", "form-radio", "form-checkbox", "form-select","form-textarea"]:
            if att.has_key(i):
                name=att[i].split(".")[-1]
                default=att.get("default","")
                check=att.get("check",None)
                f=QWebField(name,default,check)
                if i=="form-textarea":
                    f.type="textarea"
                    f.trim=0
                if i=="form-checkbox":
                    f.type="checkbox"
                    f.required=0
                self.add_field(f)
        for n in e.childNodes:
            if n.nodeType==n.ELEMENT_NODE:
                self.add_template(n)
    def process_input(self,arg):
        for f in self.fields.values():
            if arg.has_key(f.name):
                f.input=arg[f.name]
                f.value=f.input
                if f.trim:
                    f.input=f.input.strip()
                f.validate(1,False)
                if f.check==None:
                    continue
                elif callable(f.check):
                    pass
                elif isinstance(f.check,str):
                    v=f.check
                    if f.check=="email":
                        v=r"/^[^@#!& ]+@[A-Za-z0-9-][.A-Za-z0-9-]{0,64}\.[A-Za-z]{2,5}$/"
                    if f.check=="date":
                        v=r"/^(19|20)\d\d-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])$/"
                    if not re.match(v[1:-1],f.input):
                        f.validate(0,False)
            else:
                f.value=f.default
        self.update()
    def validate_all(self,val=1):
        for f in self.fields.values():
            f.validate(val,0)
        self.update()
    def invalidate_all(self):
        self.validate_all(0)
    def update(self):
        self.submitted=True
        self.valid=True
        self.errors=[]
        for f in self.fields.values():
            if f.required and f.input==None:
                self.submitted=False
                self.valid=False
                self.missing.append(f.name)
            if f.invalid:
                self.valid=False
                self.error.append(f.name)
        # invalid have been submitted and 
        self.invalid=self.submitted and self.valid==False
    def collect(self):
        d={}
        for f in self.fields.values():
            d[f.name]=f.value
        return d
class QWebURLEval(QWebEval):
    def __init__(self,data):
        QWebEval.__init__(self,data)
    def __getitem__(self,expr):
        r=QWebEval.__getitem__(self,expr)
        if isinstance(r,str):
            return urllib.quote_plus(r)
        else:
            return r
class QWebHtml(QWebXml):
    """QWebHtml
    QWebURL:
    QWebField:
    QWebForm:
    QWebHtml:
        an extended template engine, with a few utility class to easily produce
        HTML, handle URLs and process forms, it adds the following magic attributes:
    
        t-href t-action t-form-text t-form-password t-form-textarea t-form-radio
        t-form-checkbox t-form-select t-option t-selected t-checked t-pager
    
    # explication URL:
    # v['tableurl']=QWebUrl({p=afdmin,saar=,orderby=,des=,mlink;meta_active=})
    # t-href="tableurl?desc=1"
    #
    # explication FORM: t-if="form.valid()"
    # Foreach i
    #   email: <input type="text" t-esc-name="i" t-esc-value="form[i].value" t-esc-class="form[i].css"/>
    #   <input type="radio" name="spamtype" t-esc-value="i" t-selected="i==form.f.spamtype.value"/>
    #   <option t-esc-value="cc" t-selected="cc==form.f.country.value"><t t-esc="cname"></option>
    # Simple forms:
    #   <input t-form-text="form.email" t-check="email"/>
    #   <input t-form-password="form.email" t-check="email"/>
    #   <input t-form-radio="form.email" />
    #   <input t-form-checkbox="form.email" />
    #   <textarea t-form-textarea="form.email" t-check="email"/>
    #   <select t-form-select="form.email"/>
    #       <option t-value="1">
    #   <input t-form-radio="form.spamtype" t-value="1"/> Cars
    #   <input t-form-radio="form.spamtype" t-value="2"/> Sprt
    """
    # QWebForm from a template
    def form(self,tname,arg=None,default=None):
        form=QWebForm(self._t[tname],arg,default)
        return form

    # HTML Att
    def eval_url(self,av,v):
        s=QWebURLEval(v).eval_format(av)
        a=s.split('?',1)
        arg={}
        if len(a)>1:
            for k,v in cgi.parse_qsl(a[1],1):
                arg[k]=v
        b=a[0].split('/',1)
        path=''
        if len(b)>1:
            path=b[1]
        u=b[0]
        return u,path,arg
    def render_att_url_(self,e,an,av,v):
        u,path,arg=self.eval_url(av,v)
        if not isinstance(v.get(u,0),QWebURL):
            out='qweb: missing url %r %r %r'%(u,path,arg)
        else:
            out=v[u].href(path,arg)
        return ' %s="%s"'%(an[6:],cgi.escape(out,1))
    def render_att_href(self,e,an,av,v):
        return self.render_att_url_(e,"t-url-href",av,v)
    def render_att_checked(self,e,an,av,v):
        if self.eval_bool(av,v):
            return ' %s="%s"'%(an[2:],an[2:])
        else:
            return ''
    def render_att_selected(self,e,an,av,v):
        return self.render_att_checked(e,an,av,v)

    # HTML Tags forms
    def render_tag_rawurl(self,e,t_att,g_att,v):
        u,path,arg=self.eval_url(t_att["rawurl"],v)
        return v[u].href(path,arg)
    def render_tag_escurl(self,e,t_att,g_att,v):
        u,path,arg=self.eval_url(t_att["escurl"],v)
        return cgi.escape(v[u].href(path,arg))
    def render_tag_action(self,e,t_att,g_att,v):
        u,path,arg=self.eval_url(t_att["action"],v)
        if not isinstance(v.get(u,0),QWebURL):
            action,input=('qweb: missing url %r %r %r'%(u,path,arg),'')
        else:
            action,input=v[u].form(path,arg)
        g_att+=' action="%s"'%action
        return self.render_element(e,g_att,v,input)
    def render_tag_form_text(self,e,t_att,g_att,v):
        f=self.eval_object(t_att["form-text"],v)
        g_att+=' type="text" name="%s" value="%s" class="%s"'%(f.name,cgi.escape(f.value,1),f.css)
        return self.render_element(e,g_att,v)
    def render_tag_form_password(self,e,t_att,g_att,v):
        f=self.eval_object(t_att["form-password"],v)
        g_att+=' type="password" name="%s" value="%s" class="%s"'%(f.name,cgi.escape(f.value,1),f.css)
        return self.render_element(e,g_att,v)
    def render_tag_form_textarea(self,e,t_att,g_att,v):
        type="textarea"
        f=self.eval_object(t_att["form-textarea"],v)
        g_att+=' name="%s" class="%s"'%(f.name,f.css)
        r="<%s%s>%s</%s>"%(type,g_att,cgi.escape(f.value,1),type)
        return r
    def render_tag_form_radio(self,e,t_att,g_att,v):
        f=self.eval_object(t_att["form-radio"],v)
        val=t_att["value"]
        g_att+=' type="radio" name="%s" value="%s"'%(f.name,val)
        if f.value==val:
            g_att+=' checked="checked"'
        return self.render_element(e,g_att,v)
    def render_tag_form_checkbox(self,e,t_att,g_att,v):
        f=self.eval_object(t_att["form-checkbox"],v)
        val=t_att["value"]
        g_att+=' type="checkbox" name="%s" value="%s"'%(f.name,val)
        if f.value==val:
            g_att+=' checked="checked"'
        return self.render_element(e,g_att,v)
    def render_tag_form_select(self,e,t_att,g_att,v):
        f=self.eval_object(t_att["form-select"],v)
        g_att+=' name="%s" class="%s"'%(f.name,f.css)
        return self.render_element(e,g_att,v)
    def render_tag_option(self,e,t_att,g_att,v):
        f=self.eval_object(e.parentNode.getAttribute("t-form-select"),v)
        val=t_att["option"]
        g_att+=' value="%s"'%(val)
        if f.value==val:
            g_att+=' selected="selected"'
        return self.render_element(e,g_att,v)

    # HTML Tags others
    def render_tag_pager(self,e,t_att,g_att,v):
        pre=t_att["pager"]
        total=int(self.eval_str(t_att["total"],v))
        start=int(self.eval_str(t_att["start"],v))
        step=int(self.eval_str(t_att.get("step","100"),v))
        scope=int(self.eval_str(t_att.get("scope","5"),v))
        # Compute Pager
        p=pre+"_"
        d={}
        d[p+"tot_size"]=total
        d[p+"tot_page"]=tot_page=total/step
        d[p+"win_start0"]=total and start
        d[p+"win_start1"]=total and start+1
        d[p+"win_end0"]=max(0,min(start+step-1,total-1))
        d[p+"win_end1"]=min(start+step,total)
        d[p+"win_page0"]=win_page=start/step
        d[p+"win_page1"]=win_page+1
        d[p+"prev"]=(win_page!=0)
        d[p+"prev_start"]=(win_page-1)*step
        d[p+"next"]=(tot_page>=win_page+1)
        d[p+"next_start"]=(win_page+1)*step
        l=[]
        begin=win_page-scope
        end=win_page+scope
        if begin<0:
            end-=begin
        if end>tot_page:
            begin-=(end-tot_page)
        i=max(0,begin)
        while i<=min(end,tot_page) and total!=step:
            l.append( { p+"page0":i, p+"page1":i+1, p+"start":i*step, p+"sel":(win_page==i) })
            i+=1
        d[p+"active"]=len(l)>1
        d[p+"list"]=l
        # Update v
        v.update(d)
        return ""

#----------------------------------------------------------
# QWeb Simple Controller
#----------------------------------------------------------
def qweb_control(self,jump='main',p=[]):
    """ qweb_control(self,jump='main',p=[]):
    A simple function to handle the controler part of your application. It
    dispatch the control to the jump argument, while ensuring that prefix
    function have been called.

    qweb_control replace '/' to '_' and strip '_' from the jump argument.

    name1
    name1_name2
    name1_name2_name3

    """
    jump=jump.replace('/','_').strip('_')
    if not hasattr(self,jump):
        return 0
    done={}
    todo=[]
    while 1:
        if jump!=None:
            tmp=""
            todo=[]
            for i in jump.split("_"):
                tmp+=i+"_";
                if not done.has_key(tmp[:-1]):
                    todo.append(tmp[:-1])
            jump=None
        elif len(todo):
            i=todo.pop(0)
            done[i]=1
            if hasattr(self,i):
                f=getattr(self,i)
                r=f(*p)
                if isinstance(r,types.StringType):
                    jump=r
        else:
            break
    return 1

#----------------------------------------------------------
# QWeb WSGI Request handler
#----------------------------------------------------------
class QWebSession(dict):
    def __init__(self,environ,**kw):
        dict.__init__(self)
        default={
            "path" : tempfile.gettempdir(),
            "cookie_name" : "QWEBSID",
            "cookie_lifetime" : 0,
            "cookie_path" : '/',
            "cookie_domain" : '',
            "limit_cache" : 1,
            "probability" : 0.01,
            "maxlifetime" : 3600,
            "disable" : 0,
        }
        for k,v in default.items():
            setattr(self,'session_%s'%k,kw.get(k,v))
        # Try to find session
        self.session_found_cookie=0
        self.session_found_url=0
        self.session_found=0
        self.session_orig=""
        # Try cookie
        c=Cookie.SimpleCookie()
        c.load(environ.get('HTTP_COOKIE', ''))
        if c.has_key(self.session_cookie_name):
            sid=c[self.session_cookie_name].value[:64]
            if re.match('[a-f0-9]+$',sid) and self.session_load(sid):
                self.session_id=sid
                self.session_found_cookie=1
                self.session_found=1
        # Try URL
        if not self.session_found_cookie:
            mo=re.search('&%s=([a-f0-9]+)'%self.session_cookie_name,environ.get('QUERY_STRING',''))
            if mo and self.session_load(mo.group(1)):
                self.session_id=mo.group(1)
                self.session_found_url=1
                self.session_found=1
        # New session
        if not self.session_found:
            self.session_id='%032x'%random.randint(1,2**128)
        self.session_trans_sid="&amp;%s=%s"%(self.session_cookie_name,self.session_id)
        # Clean old session
        if random.random() < self.session_probability:
            self.session_clean()
    def session_get_headers(self):
        h=[]
        if (not self.session_disable) and (len(self) or len(self.session_orig)):
            self.session_save()
            if not self.session_found_cookie:
                c=Cookie.SimpleCookie()
                c[self.session_cookie_name] = self.session_id
                c[self.session_cookie_name]['path'] = self.session_cookie_path
                if self.session_cookie_domain:
                    c[self.session_cookie_name]['domain'] = self.session_cookie_domain
#               if self.session_cookie_lifetime:
#                   c[self.session_cookie_name]['expires'] = TODO date localtime or not, datetime.datetime(1970, 1, 1)
                h.append(("Set-Cookie", c[self.session_cookie_name].OutputString()))
            if self.session_limit_cache:
                h.append(('Cache-Control','no-store, no-cache, must-revalidate, post-check=0, pre-check=0'))
                h.append(('Expires','Thu, 19 Nov 1981 08:52:00 GMT'))
                h.append(('Pragma','no-cache'))
        return h
    def session_load(self,sid):
        fname=os.path.join(self.session_path,'qweb_sess_%s'%sid)
        try:
            orig=file(fname).read()
            d=pickle.loads(orig)
        except:
            return
        self.session_orig=orig
        self.update(d)
        return 1
    def session_save(self):
        if not os.path.isdir(self.session_path):
            os.makedirs(self.session_path)
        fname=os.path.join(self.session_path,'qweb_sess_%s'%self.session_id)
        try:
            oldtime=os.path.getmtime(fname)
        except OSError,IOError:
            oldtime=0
        dump=pickle.dumps(self.copy())
        if (dump != self.session_orig) or (time.time() > oldtime+self.session_maxlifetime/4):
            tmpname=os.path.join(self.session_path,'qweb_sess_%s_%x'%(self.session_id,random.randint(1,2**32)))
            f=file(tmpname,'wb')
            f.write(dump)
            f.close()
            if sys.platform=='win32' and os.path.isfile(fname):
                os.remove(fname)
            os.rename(tmpname,fname)
    def session_clean(self):
        t=time.time()
        try:
            for i in [os.path.join(self.session_path,i) for i in os.listdir(self.session_path) if i.startswith('qweb_sess_')]:
                if (t > os.path.getmtime(i)+self.session_maxlifetime):
                    os.unlink(i)
        except OSError,IOError:
            pass
class QWebSessionMem(QWebSession):
    def session_load(self,sid):
        global _qweb_sessions
        if not "_qweb_sessions" in globals():
            _qweb_sessions={}
        if _qweb_sessions.has_key(sid):
            self.session_orig=_qweb_sessions[sid]
            self.update(self.session_orig)
            return 1
    def session_save(self):
        global _qweb_sessions
        if not "_qweb_sessions" in globals():
            _qweb_sessions={}
        _qweb_sessions[self.session_id]=self.copy()
class QWebSessionService:
    def __init__(self, wsgiapp, url_rewrite=0):
        self.wsgiapp=wsgiapp
        self.url_rewrite_tags="a=href,area=href,frame=src,form=,fieldset="
    def __call__(self, environ, start_response):
        # TODO
        # use QWebSession to provide environ["qweb.session"]
        return self.wsgiapp(environ,start_response)
class QWebDict(dict):
    def __init__(self,*p):
        dict.__init__(self,*p)
    def __getitem__(self,key):
        return self.get(key,"")
    def int(self,key):
        try:
            return int(self.get(key,"0"))
        except ValueError:
            return 0
class QWebListDict(dict):
    def __init__(self,*p):
        dict.__init__(self,*p)
    def __getitem__(self,key):
        return self.get(key,[])
    def appendlist(self,key,val):
        if self.has_key(key):
            self[key].append(val)
        else:
            self[key]=[val]
    def get_qwebdict(self):
        d=QWebDict()
        for k,v in self.items():
            d[k]=v[-1]
        return d
class QWebRequest:
    """QWebRequest a WSGI request handler.

    QWebRequest is a WSGI request handler that feature GET, POST and POST
    multipart methods, handles cookies and headers and provide a dict-like
    SESSION Object (either on the filesystem or in memory).

    It is constructed with the environ and start_response WSGI arguments:
    
      req=qweb.QWebRequest(environ, start_response)
    
    req has the folowing attributes :
    
      req.environ standard WSGI dict (CGI and wsgi ones)
    
    Some CGI vars as attributes from environ for convenience: 
    
      req.SCRIPT_NAME
      req.PATH_INFO
      req.REQUEST_URI
    
    Some computed value (also for convenience)
    
      req.FULL_URL full URL recontructed (http://host/query)
      req.FULL_PATH (URL path before ?querystring)
    
    Dict constructed from querystring and POST datas, PHP-like.
    
      req.GET contains GET vars
      req.POST contains POST vars
      req.REQUEST contains merge of GET and POST
      req.FILES contains uploaded files
      req.GET_LIST req.POST_LIST req.REQUEST_LIST req.FILES_LIST multiple arguments versions
      req.debug() returns an HTML dump of those vars
    
    A dict-like session object.
    
      req.SESSION the session start when the dict is not empty.
    
    Attribute for handling the response
    
      req.response_headers dict-like to set headers
      req.response_cookies a SimpleCookie to set cookies
      req.response_status a string to set the status like '200 OK'
    
      req.write() to write to the buffer
    
    req itselfs is an iterable object with the buffer, it will also also call
    start_response automatically before returning anything via the iterator.
    
    To make it short, it means that you may use
    
      return req
    
    at the end of your request handling to return the reponse to any WSGI
    application server.
    """
    #
    # This class contains part ripped from colubrid (with the permission of
    # mitsuhiko) see http://wsgiarea.pocoo.org/colubrid/
    #
    # - the class HttpHeaders
    # - the method load_post_data (tuned version)
    #
    class HttpHeaders(object):
        def __init__(self):
            self.data = [('Content-Type', 'text/html')]
        def __setitem__(self, key, value):
            self.set(key, value)
        def __delitem__(self, key):
            self.remove(key)
        def __contains__(self, key):
            key = key.lower()
            for k, v in self.data:
                if k.lower() == key:
                    return True
            return False
        def add(self, key, value):
            self.data.append((key, value))
        def remove(self, key, count=-1):
            removed = 0
            data = []
            for _key, _value in self.data:
                if _key.lower() != key.lower():
                    if count > -1:
                        if removed >= count:
                            break
                        else:
                            removed += 1
                    data.append((_key, _value))
            self.data = data
        def clear(self):
            self.data = []
        def set(self, key, value):
            self.remove(key)
            self.add(key, value)
        def get(self, key=False, httpformat=False):
            if not key:
                result = self.data
            else:
                result = []
                for _key, _value in self.data:
                    if _key.lower() == key.lower():
                        result.append((_key, _value))
            if httpformat:
                return '\n'.join(['%s: %s' % item for item in result])
            return result
    def load_post_data(self,environ,POST,FILES):
        length = int(environ['CONTENT_LENGTH'])
        DATA = environ['wsgi.input'].read(length)
        if environ.get('CONTENT_TYPE', '').startswith('multipart'):
            lines = ['Content-Type: %s' % environ.get('CONTENT_TYPE', '')]
            for key, value in environ.items():
                if key.startswith('HTTP_'):
                    lines.append('%s: %s' % (key, value))
            raw = '\r\n'.join(lines) + '\r\n\r\n' + DATA
            msg = email.message_from_string(raw)
            for sub in msg.get_payload():
                if not isinstance(sub, email.Message.Message):
                    continue
                name_dict = cgi.parse_header(sub['Content-Disposition'])[1]
                if 'filename' in name_dict:
                    # Nested MIME Messages are not supported'
                    if type([]) == type(sub.get_payload()):
                        continue
                    if not name_dict['filename'].strip():
                        continue
                    filename = name_dict['filename']
                    # why not keep all the filename? because IE always send 'C:\documents and settings\blub\blub.png'
                    filename = filename[filename.rfind('\\') + 1:]
                    if 'Content-Type' in sub:
                        content_type = sub['Content-Type']
                    else:
                        content_type = None
                    s = { "name":filename, "type":content_type, "data":sub.get_payload() }
                    FILES.appendlist(name_dict['name'], s)
                else:
                    POST.appendlist(name_dict['name'], sub.get_payload())
        else:
            POST.update(cgi.parse_qs(DATA,keep_blank_values=1))
        return DATA

    def __init__(self,environ,start_response,session=QWebSession):
        self.environ=environ
        self.start_response=start_response
        self.buffer=[]

        self.SCRIPT_NAME = environ.get('SCRIPT_NAME', '')
        self.PATH_INFO = environ.get('PATH_INFO', '')
        # extensions:
        self.FULL_URL = environ['FULL_URL'] = self.get_full_url(environ)
        # REQUEST_URI is optional, fake it if absent
        if not environ.has_key("REQUEST_URI"):
            environ["REQUEST_URI"]=urllib.quote(self.SCRIPT_NAME+self.PATH_INFO)
            if environ.get('QUERY_STRING'):
                environ["REQUEST_URI"]+='?'+environ['QUERY_STRING']
        self.REQUEST_URI = environ["REQUEST_URI"]
        # full quote url path before the ?
        self.FULL_PATH = environ['FULL_PATH'] = self.REQUEST_URI.split('?')[0]

        self.request_cookies=Cookie.SimpleCookie()
        self.request_cookies.load(environ.get('HTTP_COOKIE', ''))

        self.response_started=False
        self.response_gzencode=False
        self.response_cookies=Cookie.SimpleCookie()
        # to delete a cookie use: c[key]['expires'] = datetime.datetime(1970, 1, 1)
        self.response_headers=self.HttpHeaders()
        self.response_status="200 OK"

        self.php=None
        if self.environ.has_key("php"):
            self.php=environ["php"]
            self.SESSION=self.php._SESSION
            self.GET=self.php._GET
            self.POST=self.php._POST
            self.REQUEST=self.php._ARG
            self.FILES=self.php._FILES
        else:
            if isinstance(session,QWebSession):
                self.SESSION=session
            elif session:
                self.SESSION=session(environ)
            else:
                self.SESSION=None
            self.GET_LIST=QWebListDict(cgi.parse_qs(environ.get('QUERY_STRING', ''),keep_blank_values=1))
            self.POST_LIST=QWebListDict()
            self.FILES_LIST=QWebListDict()
            self.REQUEST_LIST=QWebListDict(self.GET_LIST)
            if environ['REQUEST_METHOD'] == 'POST':
                self.DATA=self.load_post_data(environ,self.POST_LIST,self.FILES_LIST)
                self.REQUEST_LIST.update(self.POST_LIST)
            self.GET=self.GET_LIST.get_qwebdict()
            self.POST=self.POST_LIST.get_qwebdict()
            self.FILES=self.FILES_LIST.get_qwebdict()
            self.REQUEST=self.REQUEST_LIST.get_qwebdict()
    def get_full_url(environ):
        # taken from PEP 333
        if 'FULL_URL' in environ:
            return environ['FULL_URL']
        url = environ['wsgi.url_scheme']+'://'
        if environ.get('HTTP_HOST'):
            url += environ['HTTP_HOST']
        else:
            url += environ['SERVER_NAME']
            if environ['wsgi.url_scheme'] == 'https':
                if environ['SERVER_PORT'] != '443':
                    url += ':' + environ['SERVER_PORT']
            else:
                if environ['SERVER_PORT'] != '80':
                    url += ':' + environ['SERVER_PORT']
        if environ.has_key('REQUEST_URI'):
            url += environ['REQUEST_URI']
        else:
            url += urllib.quote(environ.get('SCRIPT_NAME', ''))
            url += urllib.quote(environ.get('PATH_INFO', ''))
            if environ.get('QUERY_STRING'):
                url += '?' + environ['QUERY_STRING']
        return url
    get_full_url=staticmethod(get_full_url)
    def save_files(self):
        for k,v in self.FILES.items():
            if not v.has_key("tmp_file"):
                f=tempfile.NamedTemporaryFile()
                f.write(v["data"])
                f.flush()
                v["tmp_file"]=f
                v["tmp_name"]=f.name
    def debug(self):
        body=''
        for name,d in [
            ("GET",self.GET), ("POST",self.POST), ("REQUEST",self.REQUEST), ("FILES",self.FILES),
            ("GET_LIST",self.GET_LIST), ("POST_LIST",self.POST_LIST), ("REQUEST_LIST",self.REQUEST_LIST), ("FILES_LIST",self.FILES_LIST),
            ("SESSION",self.SESSION), ("environ",self.environ),
        ]:
            body+='<table border="1" width="100%" align="center">\n'
            body+='<tr><th colspan="2" align="center">%s</th></tr>\n'%name
            keys=d.keys()
            keys.sort()
            body+=''.join(['<tr><td>%s</td><td>%s</td></tr>\n'%(k,cgi.escape(repr(d[k]))) for k in keys])
            body+='</table><br><br>\n\n'
        return body
    def write(self,s):
        self.buffer.append(s)
    def echo(self,*s):
        self.buffer.extend([str(i) for i in s])
    def response(self):
        if not self.response_started:
            if not self.php:
                for k,v in self.FILES.items():
                    if v.has_key("tmp_file"):
                        try:
                            v["tmp_file"].close()
                        except OSError:
                            pass
                if self.response_gzencode and self.environ.get('HTTP_ACCEPT_ENCODING','').find('gzip')!=-1:
                    zbuf=StringIO.StringIO()
                    zfile=gzip.GzipFile(mode='wb', fileobj=zbuf)
                    zfile.write(''.join(self.buffer))
                    zfile.close()
                    zbuf=zbuf.getvalue()
                    self.buffer=[zbuf]
                    self.response_headers['Content-Encoding']="gzip"
                    self.response_headers['Content-Length']=str(len(zbuf))
                headers = self.response_headers.get()
                if isinstance(self.SESSION, QWebSession):
                    headers.extend(self.SESSION.session_get_headers())
                headers.extend([('Set-Cookie', self.response_cookies[i].OutputString()) for i in self.response_cookies])
                self.start_response(self.response_status, headers)
            self.response_started=True
        return self.buffer
    def __iter__(self):
        return self.response().__iter__()
    def http_redirect(self,url,permanent=1):
        if permanent:
            self.response_status="301 Moved Permanently"
        else:
            self.response_status="302 Found"
        self.response_headers["Location"]=url
    def http_404(self,msg="<h1>404 Not Found</h1>"):
        self.response_status="404 Not Found"
        if msg:
            self.write(msg)
    def http_download(self,fname,fstr,partial=0):
#       allow fstr to be a file-like object
#       if parital:
#           say accept ranages
#           parse range headers...
#           if range:
#               header("HTTP/1.1 206 Partial Content");
#               header("Content-Range: bytes $offset-".($fsize-1)."/".$fsize);
#               header("Content-Length: ".($fsize-$offset));
#               fseek($fd,$offset);
#           else:
        self.response_headers["Content-Type"]="application/octet-stream"
        self.response_headers["Content-Disposition"]="attachment; filename=\"%s\""%fname
        self.response_headers["Content-Transfer-Encoding"]="binary"
        self.response_headers["Content-Length"]="%d"%len(fstr)
        self.write(fstr)

#----------------------------------------------------------
# QWeb WSGI HTTP Server to run any WSGI app
# autorun, run an app as FCGI or CGI otherwise launch the server
#----------------------------------------------------------
class QWebWSGIHandler(BaseHTTPServer.BaseHTTPRequestHandler):
    def log_message(self,*p):
        if self.server.log:
            return BaseHTTPServer.BaseHTTPRequestHandler.log_message(self,*p)
    def address_string(self):
        return self.client_address[0]
    def start_response(self,status,headers):
        l=status.split(' ',1)
        self.send_response(int(l[0]),l[1])
        ctype_sent=0
        for i in headers:
            if i[0].lower()=="content-type":
                ctype_sent=1
            self.send_header(*i)
        if not ctype_sent:
            self.send_header("Content-type", "text/html")
        self.end_headers()
        return self.write
    def write(self,data):
        try:
            self.wfile.write(data)
        except (socket.error, socket.timeout),e:
            print e
    def bufferon(self):
        if not getattr(self,'wfile_buf',0):
            self.wfile_buf=1
            self.wfile_bak=self.wfile
            self.wfile=StringIO.StringIO()
    def bufferoff(self):
        if self.wfile_buf:
            buf=self.wfile
            self.wfile=self.wfile_bak
            self.write(buf.getvalue())
            self.wfile_buf=0
    def serve(self,type):
        path_info, parameters, query = urlparse.urlparse(self.path)[2:5]
        environ = {
            'wsgi.version':         (1,0),
            'wsgi.url_scheme':      'http',
            'wsgi.input':           self.rfile,
            'wsgi.errors':          sys.stderr,
            'wsgi.multithread':     0,
            'wsgi.multiprocess':    0,
            'wsgi.run_once':        0,
            'REQUEST_METHOD':       self.command,
            'SCRIPT_NAME':          '',
            'QUERY_STRING':         query,
            'CONTENT_TYPE':         self.headers.get('Content-Type', ''),
            'CONTENT_LENGTH':       self.headers.get('Content-Length', ''),
            'REMOTE_ADDR':          self.client_address[0],
            'REMOTE_PORT':          str(self.client_address[1]),
            'SERVER_NAME':          self.server.server_address[0],
            'SERVER_PORT':          str(self.server.server_address[1]),
            'SERVER_PROTOCOL':      self.request_version,
            # extention
            'FULL_PATH':            self.path,
            'qweb.mode':            'standalone',
        }
        if path_info:
            environ['PATH_INFO'] = urllib.unquote(path_info)
        for key, value in self.headers.items():
            environ['HTTP_' + key.upper().replace('-', '_')] = value
        # Hack to avoid may TCP packets
        self.bufferon()
        appiter=self.server.wsgiapp(environ, self.start_response)
        for data in appiter:
            self.write(data)
            self.bufferoff()
        self.bufferoff()
    def do_GET(self):
        self.serve('GET')
    def do_POST(self):
        self.serve('GET')
class QWebWSGIServer(SocketServer.ThreadingMixIn, BaseHTTPServer.HTTPServer):
    """ QWebWSGIServer
        qweb_wsgi_autorun(wsgiapp,ip='127.0.0.1',port=8080,threaded=1)
        A WSGI HTTP server threaded or not and a function to automatically run your
        app according to the environement (either standalone, CGI or FastCGI).

        This feature is called QWeb autorun. If you want to  To use it on your
        application use the following lines at the end of the main application
        python file:

        if __name__ == '__main__':
            qweb.qweb_wsgi_autorun(your_wsgi_app)

        this function will select the approriate running mode according to the
        calling environement (http-server, FastCGI or CGI).
    """
    def __init__(self, wsgiapp, ip, port, threaded=1, log=1):
        BaseHTTPServer.HTTPServer.__init__(self, (ip, port), QWebWSGIHandler)
        self.wsgiapp = wsgiapp
        self.threaded = threaded
        self.log = log
    def process_request(self,*p):
        if self.threaded:
            return SocketServer.ThreadingMixIn.process_request(self,*p)
        else:
            return BaseHTTPServer.HTTPServer.process_request(self,*p)
def qweb_wsgi_autorun(wsgiapp,ip='127.0.0.1',port=8080,threaded=1,log=1,callback_ready=None):
    if sys.platform=='win32':
        fcgi=0
    else:
        fcgi=1
        sock = socket.fromfd(0, socket.AF_INET, socket.SOCK_STREAM)
        try:
            sock.getpeername()
        except socket.error, e:
            if e[0] == errno.ENOTSOCK:
                fcgi=0
    if fcgi or os.environ.has_key('REQUEST_METHOD'):
        import fcgi
        fcgi.WSGIServer(wsgiapp,multithreaded=False).run()
    else:
        if log:
            print 'Serving on %s:%d'%(ip,port)
        s=QWebWSGIServer(wsgiapp,ip=ip,port=port,threaded=threaded,log=log)
        if callback_ready:
            callback_ready()
        try:
            s.serve_forever()
        except KeyboardInterrupt,e:
            sys.excepthook(*sys.exc_info())

#----------------------------------------------------------
# Qweb Documentation
#----------------------------------------------------------
def qweb_doc():
    body=__doc__
    for i in [QWebXml ,QWebHtml ,QWebForm ,QWebURL ,qweb_control ,QWebRequest ,QWebSession ,QWebWSGIServer ,qweb_wsgi_autorun]:
        n=i.__name__
        d=i.__doc__
        body+='\n\n%s\n%s\n\n%s'%(n,'-'*len(n),d)
    return body

    print qweb_doc()

#
