file.jar:		FileManager.java Util.java manifest.txt
			CLASSPATH=plugin.jar:. javac -target 1.2 -source 1.2 *.java
			jar cfm file.jar manifest.txt *.class
			jarsigner -keystore ~/webmin-keystore file.jar me
