import java.util.Vector;

// StringSplitter
// A stringsplitter object splits a string into a number of substrings,
// each separated by one separator character. Separator characters can be
// included in the string by escaping them with a \
public class StringSplitter
{
	Vector parts = new Vector();
	int pos = 0;

	StringSplitter(String str, char sep)
	{
	this(str, sep, true);
	}

	StringSplitter(String str, char sep, boolean escape)
	{
	StringBuffer current;

	parts.addElement(current = new StringBuffer());
	for(int i=0; i<str.length(); i++) {
		char c = str.charAt(i);
		if (c == '\\' && i != str.length()-1 && escape)
			current.append(str.charAt(++i));
		else if (c == sep)
			parts.addElement(current = new StringBuffer());
		else
			current.append(c);
		}
	}

	// countTokens
	// The number of tokens left in the string
	int countTokens()
	{
	return parts.size() - pos;
	}

	// hasMoreTokens
	// Can we call nextToken?
	boolean hasMoreTokens()
	{
	return pos < parts.size();
	}

	// nextToken
	// Returns the string value of the next token
	String nextToken()
	{
	if (pos < parts.size())
		return ((StringBuffer)parts.elementAt(pos++)).toString();
	else
		return null;
	}

	// gettokens
	// Returns a vector of strings split from the given input string
	Vector gettokens()
	{
	return parts;
	}
}


// StringJoiner
// The complement of StringSplitter. Takes a number of substrings and adds
// them to a string, separated by some character. If the separator character
// appears in one of the substrings, escape it with a \
class StringJoiner
{
	char sep;
	StringBuffer str = new StringBuffer();
	int count = 0;

	// Create a new StringJoiner using the given separator
	StringJoiner(char s)
	{
	sep = s;
	}

	// add
	// Add one string, and a separator
	void add(String s)
	{
	if (count != 0)
		str.append(sep);
	for(int i=0; i<s.length(); i++) {
		char c = s.charAt(i);
		if (c == sep || c == '\\') str.append('\\');
		str.append(c);
		}
	count++;
	}

	// toString
	// Get the resulting string
	public String toString()
	{
	return str.toString();
	}
}

