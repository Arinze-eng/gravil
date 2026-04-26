package hev.htproxy

/**
 * JNI wrapper expected by libhev-socks5-tunnel.so
 *
 * Native methods are registered in JNI_OnLoad.
 */
class TProxyService {
  companion object {
    init {
      System.loadLibrary("hev-socks5-tunnel")
    }
  }

  external fun TProxyStartService(configPath: String, tunFd: Int)
  external fun TProxyStopService()
  external fun TProxyGetStats(): LongArray
}
