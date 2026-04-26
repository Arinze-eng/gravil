package com.example.minimal_chat_app.vpn

import com.jcraft.jsch.Proxy
import com.jcraft.jsch.SocketFactory
import okhttp3.*
import okio.ByteString
import java.io.InputStream
import java.io.OutputStream
import java.io.PipedInputStream
import java.io.PipedOutputStream
import java.net.Socket
import java.util.concurrent.TimeUnit

class WebSocketProxy(
    private val serverUrl: String,
    private val sni: String,
    private val payload: String
) : Proxy {
    private var inputStream: PipedInputStream? = null
    private var outputStream: PipedOutputStream? = null
    private var webSocket: WebSocket? = null
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.SECONDS)
        .writeTimeout(0, TimeUnit.SECONDS)
        .build()

    override fun connect(socketFactory: SocketFactory?, host: String?, port: Int, timeout: Int) {
        val out = PipedOutputStream()
        val `in` = PipedInputStream(out)
        val outToWs = PipedOutputStream()
        val inFromWs = PipedInputStream(outToWs)

        this.inputStream = inFromWs
        this.outputStream = out

        val request = Request.Builder()
            .url(serverUrl)
            .header("Host", sni)
            .header("Upgrade", "websocket")
            .header("Connection", "Upgrade")
            .build()

        val listener = object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                // Send payload after handshake if needed
                val formattedPayload = payload
                    .replace("[crlf]", "\r\n")
                    .replace("[ua]", "Dalvik/2.1.0")
                    .replace("[host]", host ?: "")
                    .replace("[port]", port.toString())
                
                webSocket.send(formattedPayload)
            }

            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                outToWs.write(bytes.toByteArray())
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                // Handle failure
            }
        }

        webSocket = client.newWebSocket(request, listener)

        // Thread to read from outputStream and send to WebSocket
        Thread {
            val buffer = ByteArray(8192)
            val pipedIn = PipedInputStream(out)
            try {
                while (true) {
                    val read = pipedIn.read(buffer)
                    if (read == -1) break
                    webSocket?.send(ByteString.of(buffer, 0, read))
                }
            } catch (e: Exception) {
                // Handle error
            }
        }.start()
    }

    override fun getInputStream(): InputStream? = inputStream
    override fun getOutputStream(): OutputStream? = outputStream
    override fun getSocket(): Socket? = null
    override fun close() {
        webSocket?.close(1000, "Closed by user")
    }
}
