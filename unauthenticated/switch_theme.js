(function () {
    let firstCombinationPressed = false;
    document.addEventListener("keydown", function (event) {
        // Check for Ctrl+Alt+Shift+0
        if (event.ctrlKey && event.altKey && event.keyCode === 84) {
            firstCombinationPressed = true;

            // Set a timeout to reset the state after a short period (e.g., 1 seconds)
            setTimeout(() => {
                firstCombinationPressed = false;
            }, 1000);
        }
        if (firstCombinationPressed && event.shiftKey &&
            (event.keyCode === 65 || event.keyCode === 71 || event.keyCode === 76)) {
            const theme =
                event.keyCode === 65 ? 1 :
                event.keyCode === 71 ? 2 :
                event.keyCode === 76 ? 3 : null;
            firstCombinationPressed = false;
            try {
                top.document.documentElement.style.filter = 'grayscale(100%) blur(0.5px) brightness(0.75) opacity(0.5)';
                top.document.documentElement.style.cursor = 'wait';
                top.document.documentElement.style.pointerEvents = 'none';
            } catch (error) {}
            top.location.href = __webmin_webprefix__ + "/switch_theme.cgi?theme=" + theme + "";
        }
    });
})();
