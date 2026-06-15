import './style.css'
import img3101 from './assets/IMG_3101.png'
import img3104 from './assets/IMG_3104.png'
import img3107 from './assets/IMG_3107.png'
import iconImg from './assets/icon.png'

const images = {
  '3101': img3101,
  '3104': img3104,
  '3107': img3107,
  'icon': iconImg,
}

document.querySelectorAll('[data-img]').forEach(el => {
  el.src = images[el.dataset.img]
})

const favicon = document.querySelector('link[rel="icon"]')
if (favicon) favicon.href = iconImg
