document.addEventListener('DOMContentLoaded', () => {
    // Typing Simulation
    const typingEl = document.getElementById('typingEffect');
    const scenarios = [
        "Dinner 1200 with Friends",
        "Taxi 450 Ash paid",
        "Groceries 3000 split equally",
        "Pizza 800 for Me and Sam"
    ];

    let sIdx = 0;
    let charIdx = 0;
    let isDeleting = false;
    let delta = 100;

    function tick() {
        const full = scenarios[sIdx];
        
        if (isDeleting) {
            typingEl.textContent = full.substring(0, charIdx - 1);
            charIdx--;
            delta = 50;
        } else {
            typingEl.textContent = full.substring(0, charIdx + 1);
            charIdx++;
            delta = 100;
        }

        if (!isDeleting && charIdx === full.length) {
            isDeleting = true;
            delta = 3000; // Pause at top
        } else if (isDeleting && charIdx === 0) {
            isDeleting = false;
            sIdx = (sIdx + 1) % scenarios.length;
            delta = 500;
        }

        setTimeout(tick, delta);
    }

    if (typingEl) tick();

    // Scroll reveal logic
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = "1";
                entry.target.style.transform = "translateY(0)";
            }
        });
    }, { threshold: 0.1 });

    document.querySelectorAll('.card, .hero h1, .hero p, .mockup-container').forEach(el => {
        el.style.opacity = "0";
        el.style.transform = "translateY(30px)";
        el.style.transition = "all 0.8s cubic-bezier(0.16, 1, 0.3, 1)";
        observer.observe(el);
    });
});
