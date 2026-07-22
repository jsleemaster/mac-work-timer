public enum GWWebMenuClickScript {
    public static func make(label: String) -> String {
        let encodedLabel = label
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return #"""
        (() => {
          const wanted = 'LABEL';
          const triggerPersonnelMenu = (win) => {
            try {
              if (typeof win.onclickTopCustomMenu === 'function') {
                win.onclickTopCustomMenu(
                  700000000,
                  '%EC%9D%B8%EC%82%AC/%EA%B7%BC%ED%83%9C',
                  '',
                  '',
                  '',
                  'N'
                );
                return true;
              }
              for (let index = 0; index < win.frames.length; index += 1) {
                if (triggerPersonnelMenu(win.frames[index])) return true;
              }
            } catch (_) {}
            return false;
          };
          const visit = (win) => {
            try {
              const elements = Array.from(win.document.querySelectorAll('*'));
              const match = elements.find((element) => {
                const text = (element.textContent || '').replace(/\s+/g, ' ').trim();
                return text === wanted;
              });
              if (match) {
                const clickable = match.closest('a, button, [role="menuitem"], [onclick]') || match;
                clickable.click();
                return true;
              }
              for (let index = 0; index < win.frames.length; index += 1) {
                if (visit(win.frames[index])) return true;
              }
            } catch (_) {}
            return false;
          };
          if (wanted === '인사/근태' && triggerPersonnelMenu(window)) {
            return true;
          }
          return visit(window);
        })()
        """#.replacingOccurrences(of: "LABEL", with: encodedLabel)
    }
}
