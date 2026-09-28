package it.thof.app;

import android.content.Context;
import android.os.Bundle;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        WebView webView = getBridge() != null ? getBridge().getWebView() : null;
        if (webView != null) {
            webView.addJavascriptInterface(new Object() {
                @JavascriptInterface
                public void print() {
                    runOnUiThread(() -> {
                        PrintManager printManager = (PrintManager) getSystemService(Context.PRINT_SERVICE);
                        if (printManager != null) {
                            String jobName = "THOF Stampa";
                            PrintDocumentAdapter printAdapter = webView.createPrintDocumentAdapter(jobName);
                            printManager.print(jobName, printAdapter, new PrintAttributes.Builder().build());
                        }
                    });
                }
            }, "AndroidPrinter");
        }
    }
}
