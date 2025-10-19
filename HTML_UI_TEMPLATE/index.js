<!--    Sidebar-->
function openNav() {
    document.getElementById("mySidebar").style.width = "250px";
    document.getElementById("main").style.marginLeft = "250px";
}

function closeNav() {
    document.getElementById("mySidebar").style.width = "0";
    document.getElementById("main").style.marginLeft= "0";
}


// Image gallery
    function openModal() {
    document.getElementById("myModal").style.display = "block";
}

    function closeModal() {
    document.getElementById("myModal").style.display = "none";
}

    var slideIndex = 1;
    showSlides(slideIndex);

    function plusSlides(n) {
    showSlides(slideIndex += n);
}

    function currentSlide(n) {
    showSlides(slideIndex = n);
}

    function showSlides(n) {
    var i;
    var slides = document.getElementsByClassName("mySlides");
    var dots = document.getElementsByClassName("demo");
    var captionText = document.getElementById("caption");
    if (n > slides.length) {slideIndex = 1}
    if (n < 1) {slideIndex = slides.length}
    for (i = 0; i < slides.length; i++) {
    slides[i].style.display = "none";
}
    for (i = 0; i < dots.length; i++) {
    dots[i].className = dots[i].className.replace(" active", "");
}
    slides[slideIndex-1].style.display = "block";
    dots[slideIndex-1].className += " active";
    captionText.innerHTML = dots[slideIndex-1].alt;
}


//AJAX GALLERY
window.addEventListener("click", () => {
    // (A) GET ALL IMAGES

    var all = document.querySelectorAll(".gallery img");
    console.log(all);
    // (B) CLICK ON IMAGE TO TOGGLE FULLSCREEN
    if (all.length>0) { for (let img of all) {
        img.onclick = () => { img.classList.toggle("full"); };
    }}
});