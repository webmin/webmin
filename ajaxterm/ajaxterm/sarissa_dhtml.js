/**
 * ====================================================================
 * About
 * ====================================================================
 * Sarissa cross browser XML library - AJAX module
 * @version 0.9.6.1
 * @author: Copyright Manos Batsis, mailto: mbatsis at users full stop sourceforge full stop net
 *
 * This module contains some convinient AJAX tricks based on Sarissa 
 *
 * ====================================================================
 * Licence
 * ====================================================================
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 or
 * the GNU Lesser General Public License version 2.1 as published by
 * the Free Software Foundation (your choice between the two).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License or GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * or GNU Lesser General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 * or visit http://www.gnu.org
 *
 */
/**
 * Update an element with response of a GET request on the given URL. 
 * @addon
 * @param sFromUrl the URL to make the request to
 * @param oTargetElement the element to update
 * @param xsltproc (optional) the transformer to use on the returned
 *                  content before updating the target element with it
 */
Sarissa.updateContentFromURI = function(sFromUrl, oTargetElement, xsltproc) {
    try{
        oTargetElement.style.cursor = "wait";
        var xmlhttp = new XMLHttpRequest();
        xmlhttp.open("GET", sFromUrl);
        function sarissa_dhtml_loadHandler() {
            if (xmlhttp.readyState == 4) {
                oTargetElement.style.cursor = "auto";
                Sarissa.updateContentFromNode(xmlhttp.responseXML, oTargetElement, xsltproc);
            };
        };
        xmlhttp.onreadystatechange = sarissa_dhtml_loadHandler;
        xmlhttp.send(null);
        oTargetElement.style.cursor = "auto";
    }
    catch(e){
        oTargetElement.style.cursor = "auto";
        throw e;
    };
};

/**
 * Update an element's content with the given DOM node.
 * @addon
 * @param sFromUrl the URL to make the request to
 * @param oTargetElement the element to update
 * @param xsltproc (optional) the transformer to use on the given 
 *                  DOM node before updating the target element with it
 */
Sarissa.updateContentFromNode = function(oNode, oTargetElement, xsltproc) {
    try {
        oTargetElement.style.cursor = "wait";
        Sarissa.clearChildNodes(oTargetElement);
        // check for parsing errors
        var ownerDoc = oNode.nodeType == Node.DOCUMENT_NODE?oNode:oNode.ownerDocument;
        if(ownerDoc.parseError && ownerDoc.parseError != 0) {
            var pre = document.createElement("pre");
            pre.appendChild(document.createTextNode(Sarissa.getParseErrorText(ownerDoc)));
            oTargetElement.appendChild(pre);
        }
        else {
            // transform if appropriate
            if(xsltproc) {
                oNode = xsltproc.transformToDocument(oNode);
            };
            // be smart, maybe the user wants to display the source instead
            if(oTargetElement.tagName.toLowerCase == "textarea" || oTargetElement.tagName.toLowerCase == "input") {
                oTargetElement.value = Sarissa.serialize(oNode);
            }
            else {
                // ok that was not smart; it was paranoid. Keep up the good work by trying to use DOM instead of innerHTML
                if(oNode.nodeType == Node.DOCUMENT_NODE || oNode.ownerDocument.documentElement == oNode) {
                    oTargetElement.innerHTML = Sarissa.serialize(oNode);
                }
                else{
                    oTargetElement.appendChild(oTargetElement.ownerDocument.importNode(oNode, true));
                };
            };  
        };
    }
    catch(e) {
        throw e;
    }
    finally{
        oTargetElement.style.cursor = "auto";
    };
};

