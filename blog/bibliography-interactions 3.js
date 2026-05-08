// Enhanced Citation Interactions for Quarto
document.addEventListener('DOMContentLoaded', function() {
    
    // Enhance citation hover behavior
    const citations = document.querySelectorAll('.citation, a[href^="#ref-"]');
    
    citations.forEach(citation => {
        // Add smooth hover animations
        citation.style.transition = 'all 0.2s ease';
        
        citation.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-1px)';
            this.style.boxShadow = '0 2px 4px rgba(0,0,0,0.1)';
        });
        
        citation.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0)';
            this.style.boxShadow = 'none';
        });
    });
    
    // Add click-to-highlight functionality for references
    const referenceEntries = document.querySelectorAll('.csl-entry, .references li');
    
    referenceEntries.forEach(entry => {
        entry.addEventListener('click', function() {
            // Remove highlighting from other entries
            referenceEntries.forEach(e => e.classList.remove('highlighted'));
            
            // Highlight clicked entry
            this.classList.add('highlighted');
            
            // Auto-remove highlight after 3 seconds
            setTimeout(() => {
                this.classList.remove('highlighted');
            }, 3000);
        });
    });
    
    // Add copy DOI/URL functionality
    const referenceLinks = document.querySelectorAll('.csl-entry a[href*="doi.org"], .csl-entry a[href*="http"]');
    
    referenceLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            if (e.ctrlKey || e.metaKey) {
                e.preventDefault();
                navigator.clipboard.writeText(this.href).then(() => {
                    // Show temporary copy confirmation
                    const originalText = this.textContent;
                    this.textContent = 'Copied!';
                    this.style.color = '#059669';
                    
                    setTimeout(() => {
                        this.textContent = originalText;
                        this.style.color = '';
                    }, 1000);
                });
            }
        });
        
        // Add tooltip for copy functionality
        link.title = 'Ctrl/Cmd+Click to copy link';
    });
    
    // Add back-to-citation functionality
    const footnoteBacklinks = document.querySelectorAll('.footnote-back, a[href^="#fnref"]');
    
    footnoteBacklinks.forEach(backlink => {
        backlink.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href').substring(1);
            const target = document.getElementById(targetId);
            
            if (target) {
                target.scrollIntoView({ behavior: 'smooth', block: 'center' });
                
                // Briefly highlight the target
                target.style.backgroundColor = 'rgba(59, 130, 246, 0.2)';
                setTimeout(() => {
                    target.style.backgroundColor = '';
                }, 1000);
            }
        });
    });
    
    // Add keyboard navigation for citations
    document.addEventListener('keydown', function(e) {
        if (e.ctrlKey && e.key === 'r') {
            e.preventDefault();
            const referencesSection = document.getElementById('references') || 
                                    document.querySelector('.references') ||
                                    document.querySelector('#refs');
            
            if (referencesSection) {
                referencesSection.scrollIntoView({ behavior: 'smooth' });
            }
        }
    });
    
    // Add reference counter
    const addReferenceCounter = () => {
        const referencesSection = document.getElementById('references') || 
                                document.querySelector('.references') ||
                                document.querySelector('#refs');
        
        if (referencesSection) {
            const entries = referencesSection.querySelectorAll('.csl-entry, li');
            const counter = document.createElement('p');
            counter.className = 'reference-counter';
            counter.textContent = `${entries.length} reference${entries.length !== 1 ? 's' : ''}`;
            counter.style.cssText = `
                font-size: 0.9rem;
                color: #6b7280;
                margin-bottom: 1rem;
                font-style: italic;
            `;
            
            const heading = referencesSection.querySelector('h1, h2, h3');
            if (heading && heading.parentNode) {
                heading.parentNode.insertBefore(counter, heading.nextSibling);
            }
        }
    };
    
    // Initialize reference counter
    addReferenceCounter();
    
    // Add print-friendly styling toggle
    const addPrintButton = () => {
        const referencesSection = document.getElementById('references') || 
                                document.querySelector('.references') ||
                                document.querySelector('#refs');
        
        if (referencesSection && window.matchMedia('screen').matches) {
            const printBtn = document.createElement('button');
            printBtn.textContent = 'Print References';
            printBtn.className = 'print-references-btn';
            printBtn.style.cssText = `
                background: #3b82f6;
                color: white;
                border: none;
                padding: 0.5rem 1rem;
                border-radius: 4px;
                cursor: pointer;
                font-size: 0.9rem;
                margin-bottom: 1rem;
                transition: background-color 0.2s;
            `;
            
            printBtn.addEventListener('click', () => {
                window.print();
            });
            
            printBtn.addEventListener('mouseenter', () => {
                printBtn.style.backgroundColor = '#2563eb';
            });
            
            printBtn.addEventListener('mouseleave', () => {
                printBtn.style.backgroundColor = '#3b82f6';
            });
            
            const heading = referencesSection.querySelector('h1, h2, h3');
            if (heading && heading.parentNode) {
                heading.parentNode.insertBefore(printBtn, heading.nextSibling);
            }
        }
    };
    
    // Initialize print button
    addPrintButton();
});

// Add CSS for highlighted entries
const style = document.createElement('style');
style.textContent = `
    .csl-entry.highlighted,
    .references li.highlighted {
        background-color: rgba(59, 130, 246, 0.1) !important;
        border-left-color: #1d4ed8 !important;
        transform: translateX(4px) !important;
        box-shadow: 0 2px 8px rgba(59, 130, 246, 0.2) !important;
    }
    
    .reference-counter {
        user-select: none;
    }
`;
document.head.appendChild(style);
