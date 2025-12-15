var shell = WScript.CreateObject("WScript.Shell");

try {
    // Używamy "cmd /c start", aby Windows rozwiązał ścieżkę za nas
    // 0 na końcu oznacza, że okno konsoli CMD się ukryje
    shell.Run("cmd /c start chrome", 0); 
} catch (e) {
    WScript.Echo("Błąd: " + e.description);
}
