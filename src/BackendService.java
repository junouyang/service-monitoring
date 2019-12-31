import org.apache.commons.io.IOUtils;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.net.URL;
import java.util.*;
import java.util.concurrent.TimeUnit;

/**
 * Created by jun.ouyang on 6/16/16.
 */
public class BackendService extends HttpServlet {

    private int port;
    private Map<String, Integer> backendPorts;
    private volatile int requestCount = 1;

    private int count = 0;
    private long totalTime = 0;
    private List<Thread> threads = new LinkedList<>();

    public BackendService(int port, Map<String, Integer> backendPorts) {
        this.port = port;
        this.backendPorts = backendPorts;
    }

    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        count++;
        long start = System.currentTimeMillis();
        System.out.println("************ " + request.getRequestURL());

        String name = request.getParameter("name");
        System.out.println("Received request : " + name);
        // Declare response encoding and types
        response.setContentType("text/html; charset=utf-8");

        // Write back response
        PrintWriter writer = response.getWriter();
        writer.println("<h1>From port " + port + " </h1>" + name);
        if (backendPorts!= null && !backendPorts.isEmpty()) {
            for (int i = 0; i < requestCount; i++) {
                for (Map.Entry<String, Integer> backendPort : backendPorts.entrySet()) {
                    for (int j = 2; j < 4; j++) {
                        String backendName = getBackendName(backendPort.getKey(), j);
                        connectToDatabaseByThread(writer, backendName, name, backendPort.getValue());
                    }
                    connectToDatabase(writer, getBackendName(backendPort.getKey(),1), name, backendPort.getValue());
                }
            }
            waitThreadsToFinish();
        }

        // Declare response status code
        response.setStatus(HttpServletResponse.SC_OK);
        try {
            int timeToSleep = count % 10 == 1 ? 1000 : 100;
            TimeUnit.MILLISECONDS.sleep(new Random().nextInt(timeToSleep));
        } catch (InterruptedException e) {
        }
        totalTime += System.currentTimeMillis() - start;
        System.out.println("average : " + (totalTime / count));
        if (count == 60) {
            totalTime = 0;
        }
        if (count == 60000) {
            count = 0;
        }
    }

    public static String getBackendName(String appName, int btId) {
        return String.format("%s-bt%s", appName, btId);
    }

    private void connectToDatabaseByThread(PrintWriter writer, String endPointName, String name, int backendPort) {
        Thread thread = new Thread(() -> {
            try {
                connectToDatabase(writer, endPointName, name, backendPort);
            } catch (IOException e) {
                e.printStackTrace();
            }
        });
        threads.add(thread);
        thread.start();
    }

    private void waitThreadsToFinish() {
        threads.stream().forEach(thread -> {
            try {
                thread.join();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        });
    }

    private void connectToDatabase(PrintWriter writer, String endPointName, String name, int backendPort) throws IOException {
        URL url = new URL(String.format("http://localhost:%d/%s?name=%s" ,backendPort, endPointName, name));
        writer.println("--" + IOUtils.toString(url.openConnection().getInputStream(), "utf-8"));
        System.out.printf("--port: %d, name: %s\n", backendPort, endPointName);

    }

    public static void main(String[] args) throws Exception {
        int port = Integer.parseInt(args[1]);
        Server server = new Server(port);

        ServletContextHandler context = new ServletContextHandler(ServletContextHandler.SESSIONS);
        context.setContextPath("/");
        server.setHandler(context);

        Map<String, Integer> backendPorts = new HashMap<>();
        for(int i = 2; i < args.length; i++) {
            System.out.println("============" + args[i]);
            String[] split = args[i].split(":");
            backendPorts.put(split[0], Integer.parseInt(split[1]));
        }

        BackendService backendService = new BackendService(port, backendPorts);
        context.addServlet(new ServletHolder(backendService), "/" + getBackendName(args[0], 1));
        context.addServlet(new ServletHolder(backendService), "/" + getBackendName(args[0], 2));

        server.start();
        server.join();
    }
}
