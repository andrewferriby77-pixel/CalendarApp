import './style.css'
import iconImg from './assets/icon.png'

const SUPABASE_URL = "https://ragsjnhromycllwoltgo.supabase.co";
const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/support-contact`;
const ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJhZ3Nqbmhyb215Y2xsd29sdGdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MTExMjUsImV4cCI6MjA5NzA4NzEyNX0.x73TS2vmHwI0D1RzQIIEZhuxc7h8mEK8ylVCpQY669Q";

// Inject icon
document.querySelectorAll('[data-img="icon"]').forEach(el => { el.src = iconImg })
const favicon = document.querySelector('link[rel="icon"]')
if (favicon) favicon.href = iconImg

// Contact form
const form = document.getElementById("contact-form");
const successState = document.getElementById("success-state");
const submitBtn = document.getElementById("submit-btn");
const submitLabel = document.getElementById("submit-label");
const submitSpinner = document.getElementById("submit-spinner");
const formError = document.getElementById("form-error");

function clearErrors() {
  ["name", "email", "message"].forEach(f => {
    document.getElementById(`${f}-error`).textContent = "";
    document.getElementById(f).classList.remove("input-error");
  });
  formError.style.display = "none";
}

function showFieldError(field, msg) {
  document.getElementById(`${field}-error`).textContent = msg;
  document.getElementById(field).classList.add("input-error");
}

function setLoading(loading) {
  submitBtn.disabled = loading;
  submitLabel.textContent = loading ? "Sending…" : "Send message";
  submitSpinner.style.display = loading ? "block" : "none";
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  clearErrors();

  const name = form.name.value.trim();
  const email = form.email.value.trim();
  const message = form.message.value.trim();
  let valid = true;

  if (!name) { showFieldError("name", "Please enter your name."); valid = false; }
  if (!email) { showFieldError("email", "Please enter your email."); valid = false; }
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { showFieldError("email", "Please enter a valid email."); valid = false; }
  if (!message) { showFieldError("message", "Please write a message."); valid = false; }
  if (!valid) return;

  setLoading(true);
  try {
    const res = await fetch(FUNCTION_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${ANON_KEY}`,
      },
      body: JSON.stringify({ name, email, message }),
    });

    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "Unexpected error");

    form.style.display = "none";
    successState.style.display = "flex";
  } catch (err) {
    formError.textContent = err.message || "Something went wrong. Please try again.";
    formError.style.display = "block";
  } finally {
    setLoading(false);
  }
});

window.resetForm = () => {
  form.reset();
  clearErrors();
  form.style.display = "block";
  successState.style.display = "none";
};
