import org.apache.commons.io.IOUtils;

import java.io.IOException;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.Arrays;
import java.util.concurrent.TimeUnit;

/**
 * Created by jun.ouyang on 6/7/16.
 */
public class TestHelloWorld {
    private int count = 0;
    private String[] ports;
    long totalTime = 0;

    public static void main(String[] args) throws InterruptedException {
        TestHelloWorld testHelloWorld = new TestHelloWorld();
        testHelloWorld.ports = Arrays.copyOfRange(args, 1, args.length);

        String appName = args[0];

        while (true) {
            try {
                testHelloWorld.connectApp(appName, "client-" + System.currentTimeMillis() % 10);
            } catch (Exception e) {
                e.printStackTrace();
            }
            try {
                TimeUnit.SECONDS.sleep(2);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }

    private void connectApp(String appName, String username) throws IOException {
        String port = ports[count++ % ports.length];
        String urlPattern = "http://localhost:%s/%s-bt%s?name=%s";
        URL url1 = new URL(String.format(urlPattern, port, appName, 1, username));
        URL url2 = new URL(String.format(urlPattern, port, appName, 2, username));
        for( URL url : new URL[]{url1, url2}) {
            long start = System.currentTimeMillis();
            try {
                System.out.println(count + ", port-" + port + " : " + IOUtils.toString(url.openConnection().getInputStream(), "utf-8"));
            } catch (Exception e) {
                System.out.println("==================== connect to " + port + ":" + e.getLocalizedMessage());
            }
            totalTime += System.currentTimeMillis() - start;
            System.out.println("average : " + (totalTime / count));
            if (count == 60) {
                count = 0;
                totalTime = 0;
            }
        }
    }

    private static String repeat(char c, int times) {
        StringBuilder builder = new StringBuilder();
        for( int i = 0; i < times;i++) {
            builder.append(c);
        }
        return builder.toString();
    }
}
