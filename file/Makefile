file.jar:		FileManager.java Util.java manifest.txt
			CLASSPATH=plugin.jar:. javac -target 1.2 -source 1.2 *.java
			jar cfm file.jar manifest.txt *.class
			jarsigner -tsa http://timestamp.comodoca.com/rfc3161 -keystore ~/jameson-comodo-full-p12 -storetype pkcs12 file.jar "jameson cameron's comodo code signing ca 2 id"
