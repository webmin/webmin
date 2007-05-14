file.jar:		FileManager.java Util.java
			CLASSPATH=/usr/local/netscape7/plugins/java2/lib/javaplugin.jar:. javac -target 1.2 -source 1.2 *.java
			jar cf file.jar *.class
			[ -d "../zomos-virtual" ] && jar cf ../zomos-virtual/file.jar *.class
