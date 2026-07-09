function isAbsoluteUrl(value) {
  return /^https?:\/\//i.test(value || "");
}

function resolveImageUrl(value, baseUrl = process.env.PUBLIC_API_URL || "") {
  if (!value) return "";
  if (isAbsoluteUrl(value)) return value;
  if (!baseUrl) return value;

  const normalizedBase = baseUrl.replace(/\/$/, "");
  const normalizedPath = value.startsWith("/") ? value : `/${value}`;
  return `${normalizedBase}${normalizedPath}`;
}

module.exports = {
  isAbsoluteUrl,
  resolveImageUrl,
};
