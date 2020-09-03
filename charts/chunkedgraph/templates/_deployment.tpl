{{/* Generate deployment from .Values.<deployment> */}}
{{- define "cg.deployment" }}
{{- if .deployment.enabled }}
{{- $chartName := .args.chart }}
{{- $deploymentName := .deployment.name }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .deployment.name | quote }}
  labels:
    app: {{ .args.chart | quote }}
spec:
{{- if not .deployment.hpa.enabled }}
  replicas: {{ .deployment.replicaCount }}
{{- end }}
  selector:
    matchLabels:
      app: {{ .deployment.name | quote }}
  template:
    metadata:
      annotations:
        rollme: {{ randAlphaNum 5 | quote }}
        {{- range $key, $val := .deployment.annotations }}
        {{ $key }}: {{ $val | quote }}
        {{- end }}
      labels:
        app: {{ .deployment.name | quote }}
    spec:
      affinity:
        {{- toYaml .deployment.affinity | nindent 8 }}
      volumes:
      {{- range .args.cloudVolumeSecrets }}
      {{- $fname := . }}
      {{- $name := $fname | regexFind "^([^.]+)" }}
        - name: {{ $name | quote }}
          secret:
            secretName: {{ $fname | quote }}
      {{- end }}
      {{- if .args.datasets }}
        - name: datasets-volume
          configMap:
            name: {{ .args.chart }}-datasets
      {{- end }}
      containers:
        - name: {{ .deployment.name | quote }}
          image: >-
            {{ required "repo" .deployment.image.repository }}:{{ required "tag" .deployment.image.tag }}
          imagePullSecrets:
            {{- toYaml .deployment.image.pullSecrets | nindent 12 }}
          imagePullPolicy: {{ .deployment.image.pullPolicy | quote }}
          ports:
            {{- toYaml .deployment.ports | nindent 12 }}
          resources:
            {{- toYaml .deployment.resources | nindent 12 }}
          envFrom:
          {{- range .args.env }}
          - configMapRef:
              name: {{ printf "%s-%s" $chartName .name }}
          {{- end }}
          {{- range .deployment.env }}
          - configMapRef:
              name: {{ printf "%s-%s" $deploymentName .name }}
          {{- end }}
          volumeMounts:
          {{- range .args.cloudVolumeSecrets }}
          {{- $fname := . }}
          {{- $name := $fname | regexFind "^([^.]+)" }}
            - name: {{ $name | quote }}
              mountPath: /root/.cloudvolume/secrets/{{ $fname }}
              subPath: {{ $fname | quote }}
              readOnly: true
          {{- end }}
          {{- if .args.datasets }}
            - name: datasets-volume
              mountPath: /app/datasets
          {{- end }}
          {{- if .deployment.command }}
          command:
            {{- toYaml .deployment.command | nindent 12 }}
          {{- else }}
          command: [bash, -c, "trap : TERM INT; sleep infinity & wait"]
          {{- end }}
      nodeSelector:
        {{- toYaml .deployment.nodeSelector | nindent 8 }}
---
{{- end }}
{{- end }}
