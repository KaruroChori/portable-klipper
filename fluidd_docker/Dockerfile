FROM nginx
COPY nginx/ /etc/nginx/
RUN rm /etc/nginx/conf.d/default.conf
COPY fluidd /usr/share/nginx/html
EXPOSE 80
