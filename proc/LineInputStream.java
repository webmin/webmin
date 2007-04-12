// LineInputStream
// A stream with some useful stdio-like methods. Can be used either for
// inheriting those methods into your own input stream, or for adding them
// to some input stream.
import java.io.InputStream;
import java.io.IOException;
import java.io.EOFException;

public class LineInputStream 
{
	InputStream in;

	LineInputStream(InputStream i)
		{ in = i; }
	LineInputStream()
		{ }

	public int read() throws IOException
		{ return in.read(); }
	public int read(byte b[]) throws IOException
		{ return in.read(b); }
	public int read(byte b[], int o, int l) throws IOException
		{ return in.read(b, o, l); }
	public long skip(long n) throws IOException
		{ return in.skip(n); }
	public int available() throws IOException
		{ return in.available(); }
	public void close() throws IOException
		{ in.close(); }
	public synchronized void mark(int readlimit)
		{ in.mark(readlimit); }
	public synchronized void reset() throws IOException
		{ in.reset(); }
	public boolean markSupported()
		{ return in.markSupported(); }

	// gets
	// Read a line and return it (minus the \n)
	String gets() throws IOException, EOFException
	{
	StringBuffer buf = new StringBuffer();
	int b;
	while((b = read()) != '\n') {
		if (b == -1) throw new EOFException();
		buf.append((char)b);
		}
	if (buf.length() != 0 && buf.charAt(buf.length()-1) == '\r')
		buf.setLength(buf.length()-1);	// lose \r
	return buf.toString();
	}

	// getw
	// Read a single word, surrounded by whitespace
	String getw() throws IOException, EOFException
	{
	StringBuffer buf = new StringBuffer();
	// skip spaces
	int b;
	do {
		if ((b = read()) == -1) throw new EOFException();
		} while(Character.isSpace((char)b));
	// add characters
	do {
		buf.append((char)b);
		if ((b = read()) == -1) throw new EOFException();
		} while(!Character.isSpace((char)b));
	return buf.toString();
	}

	// readdata
	// Fill the given array completely, even if read() only reads
	// some max number of bytes at a time.
	public int readdata(byte b[]) throws IOException, EOFException
	{
	int p = 0;
	while(p < b.length)
		p += read(b, p, b.length-p);
	return b.length;
	}
}

