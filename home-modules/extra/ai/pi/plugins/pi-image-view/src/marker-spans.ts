export interface MarkerSpan { start: number; end: number; text: string }

const IMAGE_MARKER_RE = /\[Image #\d+\]/g;

export function imageMarkerSpans(text: string): MarkerSpan[] {
	return [...text.matchAll(IMAGE_MARKER_RE)].map((match) => ({
		start: match.index,
		end: match.index + match[0].length,
		text: match[0],
	}));
}

export function markerSpanAt(
	text: string,
	cursor: number,
	action: "left" | "right" | "backspace" | "delete",
): MarkerSpan | undefined {
	return imageMarkerSpans(text).find(({ start, end }) => {
		switch (action) {
			case "left":
			case "backspace": return cursor > start && cursor <= end;
			case "right":
			case "delete": return cursor >= start && cursor < end;
		}
	});
}

export function segmentAtomicImageMarkers(
	text: string,
	segmenter: Intl.Segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" }),
): Intl.SegmentData[] {
	const spans = imageMarkerSpans(text);
	if (spans.length === 0) return [...segmenter.segment(text)];
	const result: Intl.SegmentData[] = [];
	let spanIndex = 0;
	for (const segment of segmenter.segment(text)) {
		while (spanIndex < spans.length && spans[spanIndex]!.end <= segment.index) spanIndex += 1;
		const span = spans[spanIndex];
		if (span && segment.index >= span.start && segment.index < span.end) {
			if (segment.index === span.start) result.push({ segment: span.text, index: span.start, input: text });
			continue;
		}
		result.push(segment);
	}
	return result;
}
