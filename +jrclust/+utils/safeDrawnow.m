function safeDrawnow()
    %SAFEDRAWNOW Flush graphics without forcing pending callbacks when possible.
    try
        drawnow limitrate nocallbacks
    catch
        try
            drawnow limitrate
        catch
            drawnow
        end
    end
end
