export function formatTime(hours, minutes) {
  const hh = String(hours).padStart(2, "0");
  const mm = String(minutes).padStart(2, "0");
  return `${hh}:${mm}`;
}

export function parseNumericInput(input, hourMode = 24) {
  if (!input || input.trim() === "") {
    return null;
  }

  const timeMatch = input.match(/^(\d{1,2}):?(\d{2})$/);
  let hours, minutes;

  if (timeMatch) {
    hours = parseInt(timeMatch[1], 10);
    minutes = parseInt(timeMatch[2], 10);
  } else {
    const digits = input.replace(/\D/g, "");
    if (digits.length === 0) return null;
    if (digits.length <= 2) {
      hours = parseInt(digits, 10);
      minutes = 0;
    } else if (digits.length === 3) {
      hours = parseInt(digits.substring(0, 1), 10);
      minutes = parseInt(digits.substring(1, 3), 10);
    } else {
      const padded = digits.padStart(4, "0");
      hours = parseInt(padded.substring(0, 2), 10);
      minutes = parseInt(padded.substring(2, 4), 10);
    }
  }

  const maxH = Number(hourMode) === 24 ? 24 : 13;
  if (hours >= 0 && hours < maxH && minutes >= 0 && minutes <= 59) {
    return { hours, minutes };
  }
  return undefined;
}

export function calcAngle(value, type) {
  if (type === "minute") return (360 / 60) * value;
  const normalized = value % 12 === 0 ? 12 : value % 12;
  return (360 / 12) * normalized;
}

export function getPositionFromAngle(angle, radiusPercent) {
  const rad = (Math.PI / 180) * angle;
  return {
    x: 50 + radiusPercent * Math.sin(rad),
    y: 50 - radiusPercent * Math.cos(rad)
  };
}

export function getAngleFromPosition(x, y, rect) {
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;
  const deltaX = x - centerX;
  const deltaY = y - centerY;
  let angle = Math.atan2(deltaX, -deltaY) * (180 / Math.PI);
  if (angle < 0) angle += 360;
  return angle;
}

export function getDistanceFromCenter(x, y, rect) {
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;
  const deltaX = x - centerX;
  const deltaY = y - centerY;
  return Math.sqrt(deltaX * deltaX + deltaY * deltaY);
}

export function getValueFromAngle(
  angle,
  type,
  hourMode = 24,
  distance = null,
  faceWidth = null
) {
  if (type === "hour") {
    if (Number(hourMode) === 24 && distance !== null && faceWidth !== null) {
      const innerRadiusPx = faceWidth * 0.26;
      const outerRadiusPx = faceWidth * 0.43;
      const isInnerRing =
        Math.abs(distance - innerRadiusPx) <=
        Math.abs(distance - outerRadiusPx);
      const step = 360 / 12;
      let val = Math.round(angle / step) % 12;
      if (val === 0) val = 12;
      return isInnerRing ? (val === 12 ? 0 : val + 12) : val;
    }
    const step = 360 / 12;
    let value = Math.round(angle / step) % 12;
    if (value === 0) value = 12;
    return value;
  }
  const step = 360 / 12;
  return (Math.round(angle / step) % 12) * 5;
}
